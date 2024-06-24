use core::option::OptionTrait;
use core::starknet::SyscallResultTrait;
use core::result::ResultTrait;
use core::traits::{TryInto, Into};
use starknet::{ContractAddress};
use snforge_std::{
    declare, ContractClassTrait, CheatTarget, start_prank, stop_prank, start_warp, stop_warp
};

use karst::interfaces::IHandleRegistry::{IHandleRegistryDispatcher, IHandleRegistryDispatcherTrait};
use karst::interfaces::IHandle::{IHandleDispatcher, IHandleDispatcherTrait};
use karst::namespaces::handle_registry::HandleRegistry;

const HUB_ADDRESS: felt252 = 'HUB';
const ADMIN_ADDRESS: felt252 = 'ADMIN';
const USER_ONE: felt252 = 'BOB';
const USER_TWO: felt252 = 'JOHN';
const TEST_LOCAL_NAME: felt252 = 'user';

fn __setup__() -> (ContractAddress, ContractAddress) {
    // deploy handle contract
    let handle_class_hash = declare("Handles").unwrap();
    let mut calldata: Array<felt252> = array![ADMIN_ADDRESS];
    HUB_ADDRESS.serialize(ref calldata);
    let (handle_contract_address, _) = handle_class_hash.deploy(@calldata).unwrap_syscall();

    // deploy handle registry contract
    let handle_registry_class_hash = declare("HandleRegistry").unwrap();
    let mut calldata: Array<felt252> = array![HUB_ADDRESS, handle_contract_address.into()];
    let (handle_registry_contract_address, _) = handle_registry_class_hash
        .deploy(@calldata)
        .unwrap_syscall();

    return (handle_registry_contract_address, handle_contract_address);
}

// *************************************************************************
//                              TEST
// *************************************************************************

#[test]
fn test_link() {
    let (handle_registry_address, handle_contract_address) = __setup__();
    let registryDispatcher = IHandleRegistryDispatcher {
        contract_address: handle_registry_address
    };
    let handleDispatcher = IHandleDispatcher { contract_address: handle_contract_address };

    start_prank(
        CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]),
        HUB_ADDRESS.try_into().unwrap()
    );

    // mint handle
    let handle_id = handleDispatcher.mint_handle(USER_ONE.try_into().unwrap(), TEST_LOCAL_NAME);

    // link token to profile
    registryDispatcher.link(handle_id, USER_ONE.try_into().unwrap());

    // check profile was linked
    let retrieved_handle = registryDispatcher.get_handle(USER_ONE.try_into().unwrap());
    assert(retrieved_handle == handle_id, 'linking failed');

    stop_prank(CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]));
}

#[test]
#[should_panic(expected: ('PROFILE_IS_NOT_OWNER',))]
fn test_linking_fails_if_profile_address_is_not_owner() {
    let (handle_registry_address, handle_contract_address) = __setup__();
    let registryDispatcher = IHandleRegistryDispatcher {
        contract_address: handle_registry_address
    };
    let handleDispatcher = IHandleDispatcher { contract_address: handle_contract_address };

    start_prank(
        CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]),
        HUB_ADDRESS.try_into().unwrap()
    );

    // mint handle
    let handle_id = handleDispatcher.mint_handle(USER_ONE.try_into().unwrap(), TEST_LOCAL_NAME);

    // link token to profile
    registryDispatcher.link(handle_id, USER_TWO.try_into().unwrap());

    stop_prank(CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]));
}

#[test]
#[should_panic(expected: ('HANDLE_HAS_ALREADY_BEEN_LINKED',))]
fn test_does_not_link_twice_for_same_handle() {
    let (handle_registry_address, handle_contract_address) = __setup__();
    let registryDispatcher = IHandleRegistryDispatcher {
        contract_address: handle_registry_address
    };
    let handleDispatcher = IHandleDispatcher { contract_address: handle_contract_address };

    start_prank(
        CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]),
        HUB_ADDRESS.try_into().unwrap()
    );

    // mint handle
    let handle_id = handleDispatcher.mint_handle(USER_ONE.try_into().unwrap(), TEST_LOCAL_NAME);

    // link token to profile
    registryDispatcher.link(handle_id, USER_ONE.try_into().unwrap());

    // try linking again
    registryDispatcher.link(handle_id, USER_ONE.try_into().unwrap());

    stop_prank(CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]));
}

#[test]
fn test_unlink() {
    let (handle_registry_address, handle_contract_address) = __setup__();
    let registryDispatcher = IHandleRegistryDispatcher {
        contract_address: handle_registry_address
    };
    let handleDispatcher = IHandleDispatcher { contract_address: handle_contract_address };

    start_prank(
        CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]),
        HUB_ADDRESS.try_into().unwrap()
    );

    // mint handle
    let handle_id = handleDispatcher.mint_handle(USER_ONE.try_into().unwrap(), TEST_LOCAL_NAME);

    // link token to profile
    registryDispatcher.link(handle_id, USER_ONE.try_into().unwrap());

    stop_prank(CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]));

    // call unlink
    start_prank(CheatTarget::One(handle_registry_address), USER_ONE.try_into().unwrap());
    registryDispatcher.unlink(handle_id, USER_ONE.try_into().unwrap());

    // check it unlinks successfully
    let retrieved_handle = registryDispatcher.get_handle(USER_ONE.try_into().unwrap());
    assert(retrieved_handle == 0, 'unlinking failed');
    stop_prank(CheatTarget::One(handle_registry_address));
}


#[test]
#[should_panic(expected: ('CALLER_NOT_OWNER',))]
fn test_unlink_fails_if_caller_is_not_owner() {
    let (handle_registry_address, handle_contract_address) = __setup__();
    let registryDispatcher = IHandleRegistryDispatcher {
        contract_address: handle_registry_address
    };
    let handleDispatcher = IHandleDispatcher { contract_address: handle_contract_address };

    start_prank(
        CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]),
        HUB_ADDRESS.try_into().unwrap()
    );

    // mint handle
    let handle_id = handleDispatcher.mint_handle(USER_ONE.try_into().unwrap(), TEST_LOCAL_NAME);

    // link token to profile
    registryDispatcher.link(handle_id, USER_ONE.try_into().unwrap());

    stop_prank(CheatTarget::Multiple(array![handle_registry_address, handle_contract_address]));

    // call unlink
    start_prank(CheatTarget::One(handle_registry_address), USER_TWO.try_into().unwrap());
    registryDispatcher.unlink(handle_id, USER_ONE.try_into().unwrap());
    stop_prank(CheatTarget::One(handle_registry_address));
}
