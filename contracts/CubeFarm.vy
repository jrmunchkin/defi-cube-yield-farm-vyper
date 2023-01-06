# SPDX-License-Identifier: MIT
# @version ^0.3.7

from vyper.interfaces import ERC20
import interfaces.AggregatorV3Interface as AggregatorV3Interface

interface CubeToken:
    def mint(_to: address, _amount: uint256) -> bool: nonpayable

# @title CubeFarm
# @license MIT
# @author jrmunchkin
# @notice This contract creates a simple yield farming defi that rewards users for staking up their differents token with a new ERC20 token CubeToken.
# @dev The constructor takes the address of the CubeToken ERC20 and a rate.
#    The rate is used in the algorithm to calculate the rewards that should be distributed to the user.
#    The rate represents the time in seconds to be rewarded by 100% of the amount staked.
#    For example if the rate is 86400 seconds (1 day) and the amount staked is 1 ether, then the reward will be 1 ether (in CubeToken) after 1 day of staking.
#    Ownership of the CubeToken contract should be transferred to the CubeFarm contract after deployment.
#    This contract also implements the Chainlink price feed.

i_cubeToken: immutable(CubeToken)
i_rate: immutable(uint256)
i_owner: immutable(address)
s_allowedTokens: DynArray[address, 128]
s_stakers: DynArray[address, 1024]
s_stakersIndex: HashMap[address, uint256]
s_uniqueTokensStaked: HashMap[address, uint256]
s_tokenPriceFeeds: HashMap[address, address]
s_cubeBalance: HashMap[address, uint256]
s_stakingBalance: HashMap[address, HashMap[address, uint256]]
s_startTime: HashMap[address, HashMap[address, uint256]]

event TokenStaked:
    token: indexed(address)
    staker: indexed(address)
    amount: uint256

event TokenUnstaked:
    token: indexed(address)
    staker: indexed(address)
    amount: uint256

event YieldRewarded:
    staker: indexed(address)
    rewards: uint256

@external
def __init__(_cubeTokenAddress: address, _rate: uint256):
    """
    @notice contructor
    @param _cubeTokenAddress CubeToken contract address
    @param _rate rate in seconds for calculating the rewards
    """
    i_cubeToken = CubeToken(_cubeTokenAddress)
    i_rate = _rate
    i_owner = msg.sender

@external
def setPriceFeedContract(_token: address, _priceFeedAddress: address):
    """
    @notice Set the price feed for a specific token
    @param _token token address
    @param _priceFeedAddress price feed address
    """
    assert msg.sender == i_owner, "Only owner can set price feed"
    self.s_tokenPriceFeeds[_token] = _priceFeedAddress

@external
def addAllowedToken(_token: address):
    """
    @notice Add a token to the allowed tokens list
    @param _token token address to add to the list
    """
    assert msg.sender == i_owner, "Only owner can add token"
    self.s_allowedTokens.append(_token)

@external
@nonreentrant("lock")
def stakeTokens(_amount: uint256, _token: address):
    """
    @notice Allow user to stake tokens
    @param _amount amount to stake
    @param _token address of the token to stake
    @dev log an event TokenStaked when token is staked
    """
    assert _amount > 0, "Cannot stake amount 0"
    assert ERC20(_token).balanceOf(msg.sender) >= _amount, "Not enough balance"
    assert self.isTokenAllowed(_token), "Cannot stake not allowed token"
    if self.s_stakingBalance[_token][msg.sender] <= 0:
        self.s_uniqueTokensStaked[msg.sender] += 1
    if self.s_stakingBalance[_token][msg.sender] > 0:
        toTransfer: uint256 = self.getUserYieldRewardsByToken(msg.sender, _token)
        self.s_cubeBalance[msg.sender] += toTransfer
    self.s_stakingBalance[_token][msg.sender] += _amount
    if self.s_uniqueTokensStaked[msg.sender] == 1:
        self.s_stakers.append(msg.sender)
        self.s_stakersIndex[msg.sender] = len(self.s_stakers) - 1
    self.s_startTime[_token][msg.sender] = block.timestamp
    success: bool = ERC20(_token).transferFrom(msg.sender, self, _amount)
    assert success, "External call failed"
    log TokenStaked(_token, msg.sender, _amount)

@external
@nonreentrant("lock")
def unstakeTokens(_amount: uint256, _token: address):
    """
    @notice Allow user to unstake tokens
    @param _amount amount to unstake
    @param _token address of the token to unstake
    @dev log an event TokenUnstaked when token is unstaked
    """
    userBalance: uint256 = self.s_stakingBalance[_token][msg.sender]
    assert userBalance > 0, "Cannot unstake 0 blance"
    assert userBalance >= _amount, "Cannot unstake more than user balance"
    toTransfer: uint256 = self.getUserYieldRewardsByToken(msg.sender, _token)
    self.s_startTime[_token][msg.sender] = block.timestamp
    self.s_stakingBalance[_token][msg.sender] -= _amount
    self.s_cubeBalance[msg.sender] += toTransfer
    if self.s_stakingBalance[_token][msg.sender] == 0:
        self.s_uniqueTokensStaked[msg.sender] -= 1
    if self.s_uniqueTokensStaked[msg.sender] == 0:
        self.s_stakers[self.s_stakersIndex[msg.sender]] = self.s_stakers[len(self.s_stakers) - 1]
        self.s_stakers.pop()
    success: bool = ERC20(_token).transfer(msg.sender, _amount)
    assert success, "External call failed"
    log TokenUnstaked(_token, msg.sender, _amount)

@external
@nonreentrant("lock")
def claimYieldRewards():
    """
    @notice Allow user to claim his rewards
    @dev log an event YieldRewarded when rewards have been claimed
    """
    toTransfer: uint256 = self.getUserTotalYieldRewards(msg.sender)
    if self.s_cubeBalance[msg.sender] != 0:
        oldBalance: uint256 = self.s_cubeBalance[msg.sender]
        self.s_cubeBalance[msg.sender] = 0
        toTransfer += oldBalance
    for allowedToken in self.s_allowedTokens:
        self.s_startTime[allowedToken][msg.sender] = block.timestamp
    assert toTransfer > 0, "No rewards to transfer"
    i_cubeToken.mint(msg.sender, toTransfer)
    log YieldRewarded(msg.sender, toTransfer)

@internal
def isTokenAllowed(_token: address) -> bool:
    """
    @notice Check if the token is allowed
    @param _token address of the token to check
    @return isAllowed true if allowed, false ether
    """
    if _token in self.s_allowedTokens:
        return True
    return False        

@internal
@view
def getUserTotalYieldRewards(_user: address) -> uint256:
    """
    @notice Get the user total yield rewards
    @param _user address of the user
    @return totalYieldReward total yield rewards of user
    """
    totalYieldReward: uint256 = 0
    for allowedToken in self.s_allowedTokens:
        totalYieldReward = totalYieldReward + self.getUserYieldRewardsByToken(_user, allowedToken)
    return totalYieldReward

@internal
@view
def getUserYieldRewardsByToken(_user: address, _token: address) -> uint256:
    """
    @notice Get the user rewards by token
    @param _user address of the user
    @param _token address of the token
    @return rewards total rewards by specific token
    """
    if self.s_uniqueTokensStaked[_user] <= 0:
        return 0
    price: uint256 = 0
    decimals: uint256 = 0
    (price, decimals) = self.getTokenValue(_token)
    time: uint256 = self.calculateYieldTime(_user, _token) * (10**decimals)
    timeRate: uint256 = time / i_rate
    stakingPrice: uint256 = (self.s_stakingBalance[_token][_user] * price) / (10**decimals)
    return ((stakingPrice * timeRate) / (10**decimals))

@internal
@view
def getTokenValue(_token: address) -> (uint256,uint256):
    """
    @notice Get the last known value of the token thanks to Chainlink price feed
    @param _token address of the token
    @return price the last price
    @return decimals decimals of the price
    @dev Implements Chainlink price feed
    """
    priceFeedAddress: address = self.s_tokenPriceFeeds[_token]
    priceFeed: AggregatorV3Interface = AggregatorV3Interface(priceFeedAddress)
    a: uint80 = 0
    price: int256 = 0
    b: uint256 = 0
    c: uint256 = 0
    d: uint80 = 0
    (a,price,b,c,d) = priceFeed.latestRoundData()
    decimals: uint8 = priceFeed.decimals()
    return (convert(price, uint256), convert(decimals, uint256))

@internal
@view
def calculateYieldTime(_user: address, _token: address) -> uint256:
    """
    @notice Calculate since how long the user stake a specific token
    @param _user address of the user to check
    @param _token address of the token to check
    @return totalTime time since the user start to stake this token
    """
    end: uint256 = block.timestamp
    totalTime: uint256 = end - self.s_startTime[_token][_user]
    return totalTime

@external
@view
def getTotalPendingRewards(_user: address) -> uint256:
    """
    @notice Get the total of pending rewards of a specific user
    @param _user address of the user
    @return totalPendingRewards total of pending rewards
    """
    return self.getUserTotalYieldRewards(_user) + self.s_cubeBalance[_user]

@external
@view
def getCubeTokenAddress() -> address:
    """
    @notice Get Cube token address
    @return cubeTokenAddress Cube token address
    """
    return i_cubeToken.address

@external
@view
def getRate() -> uint256:
    """
    @notice Get the rate
    @return rate rate
    """
    return i_rate

@external
@view
def getPriceFeedContract(_token: address) -> address:
    """
    @notice Get the price feed address of a specific token
    @param _token address of the token
    @return priceFeedAddress price feed address
    """
    return self.s_tokenPriceFeeds[_token]

@external
@view
def getUserTokenBalance(_user: address, _token: address) -> uint256:
    """
    @notice Get the balance of a specific token staked by a user
    @param _user address of the user
    @param _token address of the token
    @return balance balance staked
    """
    return self.s_stakingBalance[_token][_user]

@external
@view
def getNumberOfTokenStaked(_user: address) -> uint256:
    """
    @notice Get the number of different tokens a user stake
    @param _user address of the user
    @return numberOfTokens number of tokens
    """
    return self.s_uniqueTokensStaked[_user]

@external
@view
def getUserTokenStartTime(_user: address, _token: address) -> uint256:
    """
    @notice Get the start time of last staking by a user on a specific token
    @param _user address of the user
    @param _token address of the token
    @return startTime start time from last staking
    """
    return self.s_startTime[_token][_user]

@external
@view
def getUserCubeBalance(_user: address) -> uint256:
    """
    @notice Get Cube balance of a specific user
    @param _user address of the user
    @return cubeBalance Cube balance
    """
    return self.s_cubeBalance[_user]

@external
@view
def getStakers() -> DynArray[address, 1024]:
    """
    @notice Get the list of stakers
    @return stakers address list of stakers
    """
    return self.s_stakers

@external
@view
def getAllowedTokens() -> DynArray[address, 128]:
    """
    @notice Get the list of allowed tokens
    @return allowedTokens address list of allowed tokens
    """
    return self.s_allowedTokens