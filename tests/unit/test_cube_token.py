from brownie import network, reverts
from scripts.helper import LOCAL_BLOCKCHAIN_ENV, get_account
from scripts.deploy import deploy_cube_token
import pytest


def test_constructor_set_up_correctly():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    cube_token = deploy_cube_token()
    admin_role = cube_token.DEFAULT_ADMIN_ROLE()
    # Act / Assert
    assert cube_token.name() == "Cube Token"
    assert cube_token.symbol() == "CUBE"
    assert cube_token.decimals() == 18
    assert cube_token.totalSupply() == 0
    assert cube_token.hasRole(admin_role, account.address)


def test_approve(amount_to_stake):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    spender = get_account(index=1)
    cube_token = deploy_cube_token()
    # Act
    approve_tx = cube_token.approve(spender.address, amount_to_stake, {"from": account})
    approve_tx.wait(1)
    # Assert
    assert cube_token.allowance(account.address, spender.address) == amount_to_stake
    assert len(approve_tx.events["Approval"]) == 1


def test_cannot_mint_if_non_minter():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    non_minter = get_account(index=1)
    cube_token = deploy_cube_token()
    # Act / Assert
    with reverts("Sender is not the minter"):
        cube_token.mint(non_minter.address, 1, {"from": non_minter})


def test_can_mint_if_minter(amount_to_stake):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    cube_token = deploy_cube_token()
    # Transfer the role to owner
    minter_role = cube_token.MINTER_ROLE()
    grant_role_tx = cube_token.grantRole(
        minter_role, account.address, {"from": account}
    )
    grant_role_tx.wait(1)
    # Act
    mint_tx = cube_token.mint(account.address, amount_to_stake, {"from": account})
    mint_tx.wait(1)
    # Assert
    assert cube_token.totalSupply() == amount_to_stake
    assert cube_token.balanceOf(account.address) == amount_to_stake
    assert len(mint_tx.events["Transfer"]) == 1


def test_cannot_grant_role_if_non_admin():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    non_admin = get_account(index=1)
    cube_token = deploy_cube_token()
    minter_role = cube_token.MINTER_ROLE()
    # Act / Assert
    with reverts("Sender cannot grant role"):
        cube_token.grantRole(minter_role, non_admin.address, {"from": non_admin})


def test_can_grant_role_if_admin():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    cube_token = deploy_cube_token()
    minter_role = cube_token.MINTER_ROLE()
    # Act
    grant_role_tx = cube_token.grantRole(
        minter_role, account.address, {"from": account}
    )
    grant_role_tx.wait(1)
    # Assert
    assert cube_token.hasRole(minter_role, account.address)


def test_cannot_revoke_role_if_non_admin():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    non_admin = get_account(index=1)
    cube_token = deploy_cube_token()
    minter_role = cube_token.MINTER_ROLE()
    # Act / Assert
    with reverts("Sender cannot revoke role"):
        cube_token.revokeRole(minter_role, non_admin.address, {"from": non_admin})


def test_can_revoke_role_if_admin():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    cube_token = deploy_cube_token()
    minter_role = cube_token.MINTER_ROLE()
    # Act
    revoke_role_tx = cube_token.revokeRole(
        minter_role, account.address, {"from": account}
    )
    revoke_role_tx.wait(1)
    # Assert
    assert not cube_token.hasRole(minter_role, account.address)


def test_can_transfer_token(amount_to_stake):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    receiver = get_account(index=1)
    cube_token = deploy_cube_token()
    # Transfer the role to owner
    minter_role = cube_token.MINTER_ROLE()
    grant_role_tx = cube_token.grantRole(
        minter_role, account.address, {"from": account}
    )
    grant_role_tx.wait(1)
    mint_tx = cube_token.mint(account.address, amount_to_stake, {"from": account})
    mint_tx.wait(1)
    # Act
    transfer_tx = cube_token.transfer(
        receiver.address, amount_to_stake, {"from": account}
    )
    transfer_tx.wait(1)
    # Assert
    assert cube_token.balanceOf(account.address) == 0
    assert cube_token.balanceOf(receiver.address) == amount_to_stake
    assert len(transfer_tx.events["Transfer"]) == 1


def test_can_transfer_from_token(amount_to_stake):
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENV:
        pytest.skip("Only for local testing")
    account = get_account()
    receiver = get_account(index=1)
    cube_token = deploy_cube_token()
    # Transfer the role to owner
    minter_role = cube_token.MINTER_ROLE()
    grant_role_tx = cube_token.grantRole(
        minter_role, account.address, {"from": account}
    )
    grant_role_tx.wait(1)
    mint_tx = cube_token.mint(account.address, amount_to_stake, {"from": account})
    mint_tx.wait(1)
    approve_tx = cube_token.approve(
        receiver.address, amount_to_stake, {"from": account}
    )
    approve_tx.wait(1)
    # Act
    transfer_from_tx = cube_token.transferFrom(
        account.address, receiver.address, amount_to_stake, {"from": receiver}
    )
    transfer_from_tx.wait(1)
    # Assert
    assert cube_token.balanceOf(account.address) == 0
    assert cube_token.balanceOf(receiver.address) == amount_to_stake
    assert len(transfer_from_tx.events["Transfer"]) == 1
