# SPDX-License-Identifier: MIT
# @version ^0.3.7

@external
def approve(_spender: address, _value: address) -> bool:
    return True

@external
def transfer(_to: address, _value: uint256) -> bool:
    return True

@external
def transferFrom(_from: address, _to: address, _value: uint256) -> bool:
    return True

@external
def deposit():
    pass

@external 
def withdraw(_wad: uint256):
    pass

@external
@view
def balanceOf(_owner: address) -> uint256:
    return 0

@external
@view
def allowance(_owner: address, _spender:address) -> uint256:
    return 0

@external
@view
def decimals() -> uint8:
    return 0

@external
@view
def name() -> String[64]:
    return ""

@external
@view
def symbol() -> String[32]:
    return ""

@external
@view
def totalSupply() -> uint256:
    return 0