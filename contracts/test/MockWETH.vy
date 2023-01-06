# SPDX-License-Identifier: MIT
# @version ^0.3.7

from vyper.interfaces import ERC20

implements: ERC20

name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)
totalSupply: public(uint256)

balances: HashMap[address, uint256]
allowances: HashMap[address, HashMap[address, uint256]]

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
    self.name = "Weth Token"
    self.symbol = "WETH"
    self.decimals = 18
    self.totalSupply = 0
    
@external
def approve(_spender: address, _amount: uint256) -> bool:
    self.allowances[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)
    return True

@external
def transfer(_to: address, _amount: uint256) -> bool:
    self._transfer(msg.sender, _to, _amount)
    return True

@external
def transferFrom(_from: address, _to: address, _amount: uint256) -> bool:
    assert self.allowances[_from][msg.sender] >= _amount, "Insufficient allowance"
    self.allowances[_from][msg.sender] -= _amount
    self._transfer(_from, _to, _amount)
    return True

@internal
def _transfer(_from: address, _to: address, _amount: uint256):
    assert self.balances[_from] >= _amount, "Insufficient balance"
    self.balances[_from] -= _amount
    self.balances[_to] += _amount
    log Transfer(_from, _to, _amount)

@external
@view
def balanceOf(_owner: address) -> uint256:
    return self.balances[_owner]

@external
@view
def allowance(_owner: address, _spender: address) -> uint256:
    return self.allowances[_owner][_spender] 