# SPDX-License-Identifier: MIT
# @version ^0.3.7

from vyper.interfaces import ERC20

implements: ERC20

# @title CubeToken
# @license MIT
# @author jrmunchkin
# @notice A simple ERC20 token with specific MINTER_ROLE for minter.

DEFAULT_ADMIN_ROLE: public(constant(bytes32)) = keccak256('DEFAULT_ADMIN_ROLE')
MINTER_ROLE: public(constant(bytes32)) = keccak256('MINTER_ROLE')

i_name: immutable(String[64])
i_symbol: immutable(String[32])
i_decimals: immutable(uint256)
s_totalSupply: uint256
s_roles: HashMap[bytes32, HashMap[address, bool]]
s_balances: HashMap[address, uint256]
s_allowances: HashMap[address, HashMap[address, uint256]]

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256

event Approval:
    sender: indexed(address)
    receiver: indexed(address)
    amount: uint256

@external
def __init__():
    """
    @notice contructor
    """
    i_name = "Cube Token"
    i_symbol = "CUBE"
    i_decimals = 18
    self.s_totalSupply = 0
    self.s_roles[DEFAULT_ADMIN_ROLE][msg.sender] = True
    
@external
def approve(_spender: address, _amount: uint256) -> bool:
    """
    @notice Set allowance amount for spender
    @param _spender address of the spender
    @param _amount amount to approve
    @return success
    @dev log an event Approval when token is approved
    """
    self.s_allowances[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)
    return True

@external
def mint(_to: address, _amount: uint256) -> bool:
    """
    @notice Allow minter to mint tokens
    @param _to address of the minter
    @param _amount amount to mint
    @dev log an event Transfer when token is minted
    """
    assert self.s_roles[MINTER_ROLE][msg.sender], "Sender is not the minter"
    self.s_totalSupply += _amount
    self.s_balances[_to] += _amount
    log Transfer(empty(address), _to, _amount)
    return True

@external
def grantRole(_role: bytes32, _to: address) -> bool:
    """
    @notice grant role to a specific address
    @param _role role to grant
    @param _to address of the user to grant role
    @return success 
    """
    assert self.s_roles[DEFAULT_ADMIN_ROLE][msg.sender], "Sender cannot grant role"
    if not self.s_roles[_role][_to]:
        self.s_roles[_role][_to] = True
    return True

@external
def revokeRole(_role: bytes32, _to: address) -> bool:
    """
    @notice revoke role to a specific address
    @param _role role to revoke
    @param _to address of the user to revoke role
    @return success 
    """
    assert self.s_roles[DEFAULT_ADMIN_ROLE][msg.sender], "Sender cannot revoke role"
    if self.s_roles[_role][_to]:
        self.s_roles[_role][_to] = False
    return True

@external
def transfer(_to: address, _amount: uint256) -> bool:
    """
    @notice Transfer from sender to address
    @param _to address of the receiver
    @param _amount amount to transfer
    @return success 
    """
    self._transfer(msg.sender, _to, _amount)
    return True

@external
def transferFrom(_from: address, _to: address, _amount: uint256) -> bool:
    """
    @notice Transfer from address to address
    @param _from address of the sender
    @param _to address of the receiver
    @param _amount amount to transfer
    @return success 
    """
    assert self.s_allowances[_from][msg.sender] >= _amount, "Insufficient allowance"
    self.s_allowances[_from][msg.sender] -= _amount
    self._transfer(_from, _to, _amount)
    return True

@internal
def _transfer(_from: address, _to: address, _amount: uint256):
    """
    @notice Transfer from address to address
    @param _from address of the sender
    @param _to address of the receiver
    @param _amount amount to transfer
    @dev log an event Transfer when token is transfered
    """
    assert self.s_balances[_from] >= _amount, "Insufficient balance"
    self.s_balances[_from] -= _amount
    self.s_balances[_to] += _amount
    log Transfer(_from, _to, _amount)

@external
@view
def hasRole(_role: bytes32, _to: address) -> bool:
    """
    @notice Check if address has role
    @param _role role to check
    @param _to address of the user to check
    @return True if granted, False either 
    """
    return self.s_roles[_role][_to]

@external
@view
def balanceOf(_owner: address) -> uint256:
    """
    @notice Get the balance of a specific address
    @param _owner address to check balance
    @return amount amount of the balance
    """
    return self.s_balances[_owner]

@external
@view
def allowance(_owner: address, _spender: address) -> uint256:
    """
    @notice Get the allowances that an address can transfer
    @param _owner address of the allowances
    @param _spender address of spender to check
    @return amount amount of the allowances
    """
    return self.s_allowances[_owner][_spender]

@external
@view
def totalSupply() -> uint256:
    """
    @notice Get the token total supply
    @return totalSupply token total supply
    """
    return self.s_totalSupply

@external
@view
def name() -> String[64]:
    """
    @notice Get the token name
    @return name token name
    """
    return i_name

@external
@view
def symbol() -> String[32]:
    """
    @notice Get the token symbol
    @return symbol token symbol
    """
    return i_symbol

@external
@view
def decimals() -> uint256:
    """
    @notice Get the token decimals
    @return decimals token decimals
    """
    return i_decimals
