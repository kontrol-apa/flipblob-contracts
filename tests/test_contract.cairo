use array::{Span, ArrayTrait, SpanTrait, ArrayTCloneImpl};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use traits::Into;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use cheatcodes::PreparedContract;
use debug::PrintTrait;
use clone::Clone;
use FlipBlob::flip::IFlipSafeDispatcher;
use FlipBlob::flip::IFlipSafeDispatcherTrait;
use FlipBlob::merc20::IERC20SafeDispatcherTrait;
use FlipBlob::merc20::IERC20SafeDispatcher;
use starknet::get_caller_address;
use FlipBlob::common;

fn deploy_contract(name: felt252, arguments:Array<felt252>) -> ContractAddress {
    let class_hash = declare(name);
    let prepared = PreparedContract {
        class_hash, constructor_calldata: @arguments
    };
    deploy(prepared).unwrap()
}

fn deploy_multiple_contracts(name: felt252, mut arguments:Array<Array<felt252>>) -> Array<ContractAddress> {
    let class_hash = declare(name);
    let mut erc20_addresses:Array<ContractAddress> = ArrayTrait::new();

    loop{
            match arguments.pop_front() {
                Option::Some(calldata) => {
                    let prepared = PreparedContract {class_hash, constructor_calldata: @calldata};
                    erc20_addresses.append (deploy(prepared).unwrap());
                },
                Option::None(_) => {
                    break erc20_addresses.clone();
                }
            };
    }
}

fn deploy_flip_and_mocketh() -> (ContractAddress,ContractAddress) {
    let mut calldata = ArrayTrait::new();
    let flipFee:u256 = 5;
    let flipFeeLow = flipFee.low.into();
    let flipFeeHigh = flipFee.high.into();

    calldata.append(starknet::contract_address_to_felt252(common::treasury()));
    calldata.append(starknet::contract_address_to_felt252(common::admin()));
    calldata.append(flipFeeLow);
    calldata.append(flipFeeHigh);

    let flip_contract_address = deploy_contract('Flip', calldata);


    let mut calldata = ArrayTrait::new();
    let initialSupply:u256 = 100000000000000000000;
    let initialSupplyLow = initialSupply.low.into();
    let initialSupplyHigh = initialSupply.high.into();

    calldata.append('MOCK_ETH');
    calldata.append('METH');
    calldata.append(initialSupplyLow);
    calldata.append(initialSupplyHigh);
    calldata.append(starknet::contract_address_to_felt252(common::treasury()));

    let meth_contract_address = deploy_contract('ERC20', calldata);
    let meth_safe_dispatcher = IERC20SafeDispatcher { contract_address:meth_contract_address };
    let balance_of_treasury =  meth_safe_dispatcher.balance_of(common::treasury()).unwrap();
    assert( balance_of_treasury == initialSupply, 'Balances dont match!');

    (flip_contract_address, meth_contract_address)
}

fn deploy_flip_and_mocketh_usdc() -> (ContractAddress, ContractAddress, ContractAddress) {
    let mut calldata = ArrayTrait::new();
    let flipFee:u256 = 5;
    let flipFeeLow = flipFee.low.into();
    let flipFeeHigh = flipFee.high.into();

    calldata.append(starknet::contract_address_to_felt252(common::treasury()));
    calldata.append(starknet::contract_address_to_felt252(common::admin()));
    calldata.append(flipFeeLow);
    calldata.append(flipFeeHigh);

    let flip_contract_address = deploy_contract('Flip', calldata);
    let mut calldatas:Array<Array<felt252>>  = ArrayTrait::new();
    
    let mut calldata = ArrayTrait::new();
    let initialSupply:u256 = 100000000000000000000;
    let initialSupplyLow = initialSupply.low.into();
    let initialSupplyHigh = initialSupply.high.into();
    calldata.append('CIRCLE USDC');
    calldata.append('USDC');
    calldata.append(initialSupplyLow);
    calldata.append(initialSupplyHigh);
    calldata.append(starknet::contract_address_to_felt252(common::treasury()));

    calldatas.append(calldata);
    let mut calldata = ArrayTrait::new();
    calldata.append('MOCK_ETH USDC');
    calldata.append('METH');
    calldata.append(initialSupplyLow);
    calldata.append(initialSupplyHigh);
    calldata.append(starknet::contract_address_to_felt252(common::treasury()));
    calldatas.append(calldata);

    let addresses:Array<ContractAddress> = deploy_multiple_contracts('ERC20',calldatas);
    let usdc_safe_dispatcher = IERC20SafeDispatcher { contract_address:*addresses.at(0) };
    let balance_of_treasury =  usdc_safe_dispatcher.balance_of(common::treasury()).unwrap();
    assert( balance_of_treasury == initialSupply, 'Balances dont match!');

    (flip_contract_address, *addresses.at(1), *addresses.at(0) )
}

fn set_token_support(ref flip_safe_dispatcher:IFlipSafeDispatcher,  flip_contract_address:@ContractAddress, erc20_contract_address:@ContractAddress, token_name:felt252) {

    start_prank(*flip_contract_address, common::admin()); // MOCK ADMIN TO ADD COIN SUPPORT
    flip_safe_dispatcher.set_token_support(token_name, *erc20_contract_address);
    stop_prank(*flip_contract_address);

    let is_supported:bool = flip_safe_dispatcher.is_token_supported(token_name).unwrap();
    assert( is_supported == true, 'Token is not Supported!');

    let querried_erc20_contract_address = flip_safe_dispatcher.get_token_address(token_name).unwrap();
    assert(querried_erc20_contract_address == *erc20_contract_address, 'Addresses Must Match!');

    let is_supported:bool = flip_safe_dispatcher.is_token_supported('MATIC').unwrap();
    assert( is_supported == false, 'MATIC is Not Supported!');
}

fn prepare_rng(ref flip_safe_dispatcher: IFlipSafeDispatcher, ref request_ids : Array<felt252>, ref fair_random_number_hashes : Array<u256>, ref random_numbers : Array<u256>){
    let mut index = 1;
    let SIZE = 20;
    loop {
        let random_number = flip_safe_dispatcher.calculate_keccak(index.into()).unwrap();
        let hash = flip_safe_dispatcher.calculate_keccak(random_number).unwrap();
        random_numbers.append(random_number);
        fair_random_number_hashes.append(hash);
        request_ids.append(index.into());

        if index == SIZE {
            break;
        } else {
            index += 1;
        };
    };
}

fn approve_and_mint(ref erc20_safe_dispatcher:IERC20SafeDispatcher, flip_contract_address:@ContractAddress, erc20_contract_address:@ContractAddress, amount: u256) {
    start_prank(*erc20_contract_address, common::user());  // MOCK USER TO FLIP
    erc20_safe_dispatcher.approve(*flip_contract_address, amount);
    erc20_safe_dispatcher.mint(common::user(), amount);
    stop_prank(*erc20_contract_address);

    start_prank(*erc20_contract_address, common::treasury()); // MOCK TREASURY TO APPROVE FLIP CONTRACT FOR SPENDING
    erc20_safe_dispatcher.approve(*flip_contract_address, amount);
    stop_prank(*erc20_contract_address);
}

fn calculate_payout (ref flip_safe_dispatcher: IFlipSafeDispatcher, wager:u256, success_count:u256 ) -> u256 {
    ((wager * (100 - flip_safe_dispatcher.get_flip_fee().unwrap()) / 100) * success_count) + (wager * success_count)  // (PROFIT) + (INITIAL_DEPOSIT) 

}
#[test]
fn test_single_erc20() {
    let (flip_contract_address, meth_contract_address) = deploy_flip_and_mocketh();
    let mut flip_safe_dispatcher = IFlipSafeDispatcher { contract_address:flip_contract_address };
    let mut meth_safe_dispatcher = IERC20SafeDispatcher { contract_address:meth_contract_address };

    set_token_support(ref flip_safe_dispatcher, @flip_contract_address, @meth_contract_address, 'METH');

    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
    prepare_rng(ref flip_safe_dispatcher, ref request_ids, ref fair_random_number_hashes, ref random_numbers);
    
    start_prank(flip_contract_address,common::admin());  // MOCK ADMIN TO WRITE FAIR RNG
    flip_safe_dispatcher.write_fair_rng_batch(request_ids.span(), fair_random_number_hashes);
    stop_prank(flip_contract_address);

    approve_and_mint(ref meth_safe_dispatcher, @flip_contract_address, @meth_contract_address ,1000000000000000000);

    let index = 0;
    let bet = 1000000;
    let pre_bet_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    flip_safe_dispatcher.issue_request(1, bet, 0, 'METH');
    stop_prank(flip_contract_address);

    let pre_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((pre_bet_balance - pre_balance ) == (bet), 'Balances dont match!'  );

     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Request already finalized', *panic_data.at(0));
       }
    }

    let post_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 

    assert((post_balance - pre_balance ) == calculate_payout(ref flip_safe_dispatcher, bet, 1), 'Balances dont match!'  );

    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    match flip_safe_dispatcher.issue_request(1, bet, 2, 'METH') {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Unsupported Coin Face.', *panic_data.at(0));
       }
    }
    stop_prank(flip_contract_address);
 }

#[test]
fn test_double_erc20() {
    let (flip_contract_address, meth_contract_address, usdc_contract_address) = deploy_flip_and_mocketh_usdc();
    let mut flip_safe_dispatcher = IFlipSafeDispatcher { contract_address:flip_contract_address };
    let mut meth_safe_dispatcher = IERC20SafeDispatcher { contract_address:meth_contract_address };
    let mut usdc_safe_dispatcher = IERC20SafeDispatcher { contract_address:usdc_contract_address };

    set_token_support(ref flip_safe_dispatcher, @flip_contract_address, @meth_contract_address, 'METH');
    set_token_support(ref flip_safe_dispatcher, @flip_contract_address, @usdc_contract_address, 'USDC');

    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
    prepare_rng(ref flip_safe_dispatcher, ref request_ids, ref fair_random_number_hashes, ref random_numbers);
    
    start_prank(flip_contract_address,common::admin());  // MOCK ADMIN TO WRITE FAIR RNG
    flip_safe_dispatcher.write_fair_rng_batch(request_ids.span(), fair_random_number_hashes);
    stop_prank(flip_contract_address);

    approve_and_mint(ref meth_safe_dispatcher, @flip_contract_address, @meth_contract_address ,100000000000000000000);
    approve_and_mint(ref usdc_safe_dispatcher, @flip_contract_address, @usdc_contract_address ,10000000000000000000);
    


    let mut index = 0;
    let mut bet = 1000000;
    let pre_bet_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    flip_safe_dispatcher.issue_request(1, bet, 0, 'METH');
    stop_prank(flip_contract_address);

    let pre_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((pre_bet_balance - pre_balance ) == (bet), 'Balances dont match!'  );

     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       }
    }

    let post_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((post_balance - pre_balance ) == calculate_payout(ref flip_safe_dispatcher, bet, 1), 'Balances dont match!');


    index = index + 1;
    bet = 11000000;
    let pre_bet_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap(); 
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    flip_safe_dispatcher.issue_request(1, bet, 0, 'USDC');
    stop_prank(flip_contract_address);

    let pre_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((pre_bet_balance - pre_balance ) == (bet), 'Balances dont match!'  );

     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       }
    }

    let post_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((post_balance - pre_balance ) == calculate_payout(ref flip_safe_dispatcher, bet, 1), 'Balances dont match!');

    index = index ;
    bet = 11000000;
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    match flip_safe_dispatcher.issue_request(1, bet, 2, 'METH') {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Unsupported Coin Face.', *panic_data.at(0));
       }
    }

    match flip_safe_dispatcher.issue_request(1, bet, 1, 'USDC') {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       
       }
    }
    stop_prank(flip_contract_address);

    match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Request already finalized.', *panic_data.at(0));
       }
    }

    match flip_safe_dispatcher.finalize_request(*request_ids.at(index + 1), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Wrong number.', *panic_data.at(0));
       }
    }

    index = index +1  ;

    match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       
       }
    }
}
#[test]
fn test_multi_bet() {
    let (flip_contract_address, meth_contract_address, usdc_contract_address) = deploy_flip_and_mocketh_usdc();
    let mut flip_safe_dispatcher = IFlipSafeDispatcher { contract_address:flip_contract_address };
    let mut meth_safe_dispatcher = IERC20SafeDispatcher { contract_address:meth_contract_address };
    let mut usdc_safe_dispatcher = IERC20SafeDispatcher { contract_address:usdc_contract_address };

    set_token_support(ref flip_safe_dispatcher, @flip_contract_address, @meth_contract_address, 'METH');
    set_token_support(ref flip_safe_dispatcher, @flip_contract_address, @usdc_contract_address, 'USDC');

    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
    prepare_rng(ref flip_safe_dispatcher, ref request_ids, ref fair_random_number_hashes, ref random_numbers);
    
    start_prank(flip_contract_address,common::admin());  // MOCK ADMIN TO WRITE FAIR RNG
    flip_safe_dispatcher.write_fair_rng_batch(request_ids.span(), fair_random_number_hashes);
    stop_prank(flip_contract_address);

    approve_and_mint(ref meth_safe_dispatcher, @flip_contract_address, @meth_contract_address ,100000000000000000000);
    approve_and_mint(ref usdc_safe_dispatcher, @flip_contract_address, @usdc_contract_address ,10000000000000000000);

    let mut index = 0;
    let mut bet = 10000000;
    let mut times = 10;
    let mut pre_bet_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    flip_safe_dispatcher.issue_request(times, bet, 0, 'METH');
    stop_prank(flip_contract_address);

    let mut pre_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((pre_bet_balance - pre_balance ) == (bet * times), 'Issue Balances dont match!'  );

     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       }
    }
    let (state, success_count) = flip_safe_dispatcher.get_request_final_state(*request_ids.at(index)).unwrap();
    assert (state == 1 , 'Transaction must be finalized!');
    assert (success_count <= times , 'Count greater than the amount');
    let mut post_balance = meth_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((post_balance - pre_balance ) == calculate_payout(ref flip_safe_dispatcher, bet, success_count), 'Balances dont match!');

    bet = 555555;
    times = 3;
    index = index + 1;
    pre_bet_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap(); 
    start_prank(flip_contract_address,common::user());  // MOCK USER TO FLIP
    flip_safe_dispatcher.issue_request(times, bet, 0, 'USDC');
    stop_prank(flip_contract_address);

    pre_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap(); 
    assert((pre_bet_balance - pre_balance ) == (bet * times), 'Issue Balances dont match!'  );
     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            (*panic_data.at(0)).print();
       }
    }
    let (state, success_count) = flip_safe_dispatcher.get_request_final_state(*request_ids.at(index)).unwrap();
    assert (state == 1 , 'Transaction must be finalized!');
    assert (success_count <= times , 'Count greater than the amount');
    post_balance = usdc_safe_dispatcher.balance_of(common::user()).unwrap();
    assert((post_balance - pre_balance ) == calculate_payout(ref flip_safe_dispatcher, bet, success_count), 'Balances donta match!');


}

