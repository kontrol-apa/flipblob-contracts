const HEAD: felt252 = 1;
const TAIL: felt252 = 0;
const INVALID: felt252 = 2;


use array::{Span, ArrayTrait, SpanTrait, ArrayTCloneImpl};
use result::ResultTrait;
use option::{Option, OptionTrait};
use traits::TryInto;
use traits::Into;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use clone::Clone;
use flipblob::flip::flipblob::IFlipSafeDispatcher;
use flipblob::flip::flipblob::IFlipSafeDispatcherTrait;
use openzeppelin::token::erc20::interface::{IERC20CamelDispatcher, IERC20CamelDispatcherTrait};
use flipblob::tests::test_utils::common_fork;
use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, PrintTrait};
use starknet::contract_address_const;

const MAX_BET_AMOUNT: u256 = 10;
fn do_a_panic(msg: felt252) {
    let mut arr = ArrayTrait::new();
    arr.append(msg);
    panic(arr);
}
fn deploy_contract(name: felt252, arguments: Array<felt252>) -> ContractAddress {
    let contract = declare(name);
    contract.deploy(@arguments).unwrap()
}

fn deploy_multiple_contracts(
    name: felt252, mut arguments: Array<Array<felt252>>
) -> Array<ContractAddress> {
    let contract = declare(name);
    let mut erc20_addresses: Array<ContractAddress> = ArrayTrait::new();

    loop {
        match arguments.pop_front() {
            Option::Some(calldata) => {
                erc20_addresses.append(contract.deploy(@calldata).unwrap());
            },
            Option::None(_) => { break erc20_addresses.clone(); }
        };
    }
}

fn deploy_flip() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let flipFee: u256 = 5;
    let flipFeeLow = flipFee.low.into();
    let flipFeeHigh = flipFee.high.into();

    calldata.append(starknet::contract_address_to_felt252(common_fork::treasury()));
    calldata.append(starknet::contract_address_to_felt252(common_fork::admin()));
    calldata.append(flipFeeLow);
    calldata.append(flipFeeHigh);
    calldata.append(starknet::contract_address_to_felt252(common_fork::finalizer()));

    let flip_contract_address = deploy_contract('Flip', calldata);

    flip_contract_address
}

fn set_token_support(
    ref flip_safe_dispatcher: IFlipSafeDispatcher,
    flip_contract_address: @ContractAddress,
    erc20_contract_address: @ContractAddress,
    max_bet_amount: u128,
    min_bet_amount: u128,
    token_name: felt252
) {
    start_prank(*flip_contract_address, common_fork::admin()); // MOCK ADMIN TO ADD COIN SUPPORT
    flip_safe_dispatcher
        .set_token_support(token_name, *erc20_contract_address, max_bet_amount, min_bet_amount);
    stop_prank(*flip_contract_address);

    let is_supported: bool = flip_safe_dispatcher.is_token_supported(token_name).unwrap();
    assert(is_supported == true, 'Token is not Supported!');

    let querried_erc20_contract_address = flip_safe_dispatcher
        .get_token_address(token_name)
        .unwrap();
    assert(querried_erc20_contract_address == *erc20_contract_address, 'Addresses Must Match!');
    let is_supported: bool = flip_safe_dispatcher.is_token_supported('MATIC').unwrap();
    assert(is_supported == false, 'MATIC is Not Supported!');
}
fn prepare_rng(ref request_ids: Array<felt252>, ref random_numbers: Array<u256>) {
    let mut index = 1;
    let SIZE = 20;
    loop {
        let random_number = keccak::keccak_u256s_le_inputs(array![index.into()].span());
        random_numbers.append(random_number);
        request_ids.append(index.into());

        if index == SIZE {
            break;
        } else {
            index += 1;
        };
    };
}

fn finish_approvals(
    ref erc20_safe_dispatcher: IERC20CamelDispatcher,
    flip_contract_address: @ContractAddress,
    erc20_contract_address: @ContractAddress,
    amount: u256
) {
    start_prank(*erc20_contract_address, common_fork::user()); // MOCK USER TO FLIP
    erc20_safe_dispatcher.approve(*flip_contract_address, amount);
    stop_prank(*erc20_contract_address);

    start_prank(
        *erc20_contract_address, common_fork::treasury()
    ); // MOCK TREASURY TO APPROVE FLIP CONTRACT FOR SPENDING
    erc20_safe_dispatcher.approve(*flip_contract_address, amount);
    stop_prank(*erc20_contract_address);
}

fn calculate_payout(
    ref flip_safe_dispatcher: IFlipSafeDispatcher, wager: u256, success_count: u256
) -> u256 {
    if success_count > 0 && success_count <= MAX_BET_AMOUNT {
        ((wager * (100 - flip_safe_dispatcher.get_flip_fee().unwrap()) / 100) * success_count)
            + (wager * success_count) // (PROFIT) + (INITIAL_DEPOSIT) 
    } else {
        0
    }
}

fn finalize_request(
    ref flip_safe_dispatcher: IFlipSafeDispatcher,
    flip_contract_address: @ContractAddress,
    finalizer: ContractAddress,
    requestId: felt252,
    randomNumber: u256,
    error_message: felt252
) {
    start_prank(*flip_contract_address, finalizer); // MOCK AFINALIZER TO FINALIZE BET
    match flip_safe_dispatcher.finalize_request(requestId, randomNumber) {
        Result::Ok(_) => {
            if error_message == 'Success' {
                'Passed.'.print()
            } else {
                panic_with_felt252('Should\'ve Panicked');
            }
        },
        Result::Err(panic_data) => {
            if error_message == 'Success' {
                panic_with_felt252((*panic_data.at(0)));
            } else {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == error_message, *panic_data.at(0));
            }
        }
    }
    stop_prank(*flip_contract_address);
}

#[test]
#[fork(
    url: "https://starknet-goerli.infura.io/v3/aac935ca55144efba9c42542cd103913",
    block_id: BlockId::Number(913114)
)]
fn test_live() {
    let flip_contract_address = deploy_flip();
    let mut flip_safe_dispatcher = IFlipSafeDispatcher { contract_address: flip_contract_address };
    let eth_contract_address = contract_address_const::<
        0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    >();

    let mut eth_camel_dispatcher = IERC20CamelDispatcher { contract_address: eth_contract_address };
    let max_bet_amount_meth: u128 = 39000000000000000;
    let min_bet_amount_meth: u128 = 100000;
    set_token_support(
        ref flip_safe_dispatcher,
        @flip_contract_address,
        @eth_contract_address,
        max_bet_amount_meth,
        min_bet_amount_meth,
        'ETH'
    );

    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
    prepare_rng(ref request_ids, ref random_numbers);

    finish_approvals(
        ref eth_camel_dispatcher, @flip_contract_address, @eth_contract_address, 1000000000000000000
    );

    let index = 0;
    let bet = min_bet_amount_meth + 10;
    let pre_bet_balance = eth_camel_dispatcher.balanceOf(common_fork::user());
    start_prank(flip_contract_address, common_fork::user()); // MOCK USER TO FLIP
    match flip_safe_dispatcher.issue_request(1, bet.into(), HEAD, 'ETH') {
        Result::Ok(_) => { 'Done.'.print(); },
        Result::Err(panic_data) => {
            panic_data.print();
            panic_with_felt252('Should have Panicked');
        }
    }
    stop_prank(flip_contract_address);
    let pre_balance = eth_camel_dispatcher.balanceOf(common_fork::user());

    pre_bet_balance.print();
    pre_balance.print();
    assert((pre_bet_balance - pre_balance) == (bet.into()), 'Balances dont match!');

    finalize_request(
        ref flip_safe_dispatcher,
        @flip_contract_address,
        common_fork::treasury(),
        *request_ids.at(index),
        *random_numbers.at(index),
        'Only Finalizer'
    );

    finalize_request(
        ref flip_safe_dispatcher,
        @flip_contract_address,
        common_fork::finalizer(),
        *request_ids.at(index),
        *random_numbers.at(index),
        'Success'
    );

    let post_balance = eth_camel_dispatcher.balanceOf(common_fork::user());
    let success_count = flip_safe_dispatcher
        .get_request_status(*request_ids.at(index))
        .unwrap()
        .into();
    assert(success_count != 0, 'TX must be finalized!');

    assert(
        (post_balance
            - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet.into(), success_count),
        'Balances dont match!'
    );

    start_prank(flip_contract_address, common_fork::user()); // MOCK USER TO FLIP
    match flip_safe_dispatcher.issue_request(1, bet.into(), INVALID, 'ETH') {
        Result::Ok(_) => 'Passed.'.print(),
        Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
            assert(*panic_data.at(0) == 'Unsupported Coin Face.', *panic_data.at(0));
        }
    }
    stop_prank(flip_contract_address);
}
