use array::{Span, ArrayTrait, SpanTrait};
use result::ResultTrait;
use option::OptionTrait;
use traits::TryInto;
use traits::Into;
use starknet::ContractAddress;
use starknet::Felt252TryIntoContractAddress;
use cheatcodes::PreparedContract;
use debug::PrintTrait;
use FlipBlob::flip::IFlipSafeDispatcher;
use FlipBlob::flip::IFlipSafeDispatcherTrait;
use FlipBlob::merc20::IERC20SafeDispatcherTrait;
use FlipBlob::merc20::IERC20SafeDispatcher;
use starknet::get_caller_address;

fn deploy_contract(name: felt252, arguments:Array<felt252>) -> ContractAddress {
    let class_hash = declare(name);
    let prepared = PreparedContract {
        class_hash, constructor_calldata: @arguments
    };
    deploy(prepared).unwrap()
}

fn prepare_rng(ref flip_safe_dispatcher: IFlipSafeDispatcher, ref request_ids : Array<felt252>, ref fair_random_number_hashes : Array<u256>, ref random_numbers : Array<u256>){
    let mut index = 0;
    let SIZE = 10;
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

fn arr_copy(mut vals: Span<u32>) -> u32 {
    let mut sum = 0_u32;

    loop {
        match vals.pop_front() {
            Option::Some(v) => {
                sum += *v;
            },
            Option::None(_) => {
                break sum;
            }
        };
    }
}



#[test]
fn test_write_batch() {

    let mut calldata = ArrayTrait::new();
    let flipFee:u256 = 5;
    let treasury:felt252= 0x034e31357d1c3693bda06d04bf4c51557514eced5a8e9973bdb772f7fb978b36;
    let flipFeeLow = flipFee.low.into();
    let flipFeeHigh = flipFee.high.into();

    calldata.append(treasury);
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
    calldata.append(treasury);

    let erc20_contract_address = deploy_contract('ERC20', calldata);

    let mut flip_safe_dispatcher = IFlipSafeDispatcher { contract_address:flip_contract_address };
    let erc20_safe_dispatcher = IERC20SafeDispatcher { contract_address:erc20_contract_address };


    let balance_of_treasury =  erc20_safe_dispatcher.balance_of(starknet::contract_address_try_from_felt252(treasury).unwrap()).unwrap();
    assert( balance_of_treasury == initialSupply, 'Balances dont match!');

    flip_safe_dispatcher.set_token_support('METH', erc20_contract_address);
    let is_supported:bool = flip_safe_dispatcher.is_token_supported('METH').unwrap();
    assert( is_supported == true, 'WETH is Supported!');

    let querried_erc20_contract_address = flip_safe_dispatcher.get_token_address('METH').unwrap();
    assert(querried_erc20_contract_address == erc20_contract_address, 'Addresses Must Match!');

    let is_supported:bool = flip_safe_dispatcher.is_token_supported('USDC').unwrap();
    assert( is_supported == false, 'USDC is Not Supported!');


    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
    prepare_rng(ref flip_safe_dispatcher, ref request_ids, ref fair_random_number_hashes, ref random_numbers);
    

    flip_safe_dispatcher.write_fair_rng_batch(request_ids.span(), fair_random_number_hashes);
    let myAddress = flip_safe_dispatcher.owner().unwrap();

    start_prank(erc20_contract_address, myAddress);
    erc20_safe_dispatcher.approve(flip_contract_address, 1000000000000000000);
    erc20_safe_dispatcher.mint(myAddress, 1000000000000000000);
    stop_prank(erc20_contract_address);

    start_prank(erc20_contract_address, starknet::contract_address_try_from_felt252(treasury).unwrap());
    erc20_safe_dispatcher.approve(flip_contract_address, 1000000000000000000);
    stop_prank(erc20_contract_address);





    let index = 0;
    // erc20_safe_dispatcher.balance_of(myAddress).unwrap().print(); 
    flip_safe_dispatcher.issue_request(1,1000000,1,'METH');
    // erc20_safe_dispatcher.balance_of(myAddress).unwrap().print(); 

    // flip_safe_dispatcher.is_token_supported('METH').unwrap().print();
    // erc20_safe_dispatcher.balance_of(myAddress).unwrap().print(); 

   let toss_result = (*random_numbers.at(index)) % 2;
    let mut success = false;
    if toss_result == 1 {
        success = true;
    }
    success.print();
     match flip_safe_dispatcher.finalize_request(*request_ids.at(index), *random_numbers.at(index) ) {
       Result::Ok(_) => 'done'.print(),
       Result::Err(panic_data) => {
            'yarrak'.print();
            assert(*panic_data.at(0) == 'Request already finalized', *panic_data.at(0));

       }
    }



 }