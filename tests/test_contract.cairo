use array::ArrayTrait;
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

fn deploy_contract(name: felt252, arguments:Array<felt252>) -> ContractAddress {
    let class_hash = declare(name);
    let prepared = PreparedContract {
        class_hash, constructor_calldata: @arguments
    };
    deploy(prepared).unwrap()
}


//#[test]
//fn test_init_request() {
//    let contract_address = deploy_contract('Flip');
//    let contract_address2 = deploy_contract('ERC20');
//    contract_address.print();
//    contract_address2.print();
//    let safe_dispatcher = IFlipSafeDispatcher { contract_address };
//    let first_request_id = safe_dispatcher.get_next_request_id().unwrap();
//    
//    assert( first_request_id == 0, 'Request id wrong');
//    safe_dispatcher.issue_request(1,19999999912312312312312322323223232323233,1).unwrap();
//    let second_request_id = safe_dispatcher.get_next_request_id().unwrap();
//    second_request_id.print();
//    let (a,b,c,d) = safe_dispatcher.get_request(0).unwrap();
//    a.print();
//    b.print();
//    c.print();
//    d.print();
//
//    assert( second_request_id == 1, 'Request id wrong');
//
//}
//    // rng = 11231231423423423423423231231233
//    // hash 0xbf0fe55b3c2b3387e0842c3c4b3f759737b3c617cf6fdf69b52d84db79341acc
//    // 86419839744980627174922957242311545107819912114511241305104172346493761755852
//#[test]
//fn test_keccak() {
//    let contract_address = deploy_contract('Flip');
//
//    let safe_dispatcher = IFlipSafeDispatcher { contract_address };
//    let keccak = safe_dispatcher.calculate_keccak(86419839744980627174922957242311545107819912114511241305104172346493761755852).unwrap();
//    let onwer = safe_dispatcher.owner().unwrap();
//    onwer.print();
//    //let x : felt252 = keccak.try_into().unwrap();
//    keccak.print();
//}
//
//#[test]
//fn test_full() {
//    let contract_address = deploy_contract('Flip');
//    let safe_dispatcher = IFlipSafeDispatcher { contract_address };
//    //write the hash of the random number
//    let addy: ContractAddress =
//                starknet::contract_address_const::<0x00d0e183745e9dae3e4e78a8ffedcce0903fc4900beace4e0abf192d4c202da3>();
//    start_prank(contract_address, addy);
//    match safe_dispatcher.write_fair_rng(0,0xbf0fe55b3c2b3387e0842c3c4b3f759737b3c617cf6fdf69b52d84db79341acc) {
//        //Result::Ok(_) => panic_with_felt252('Should have panicked'),
//        Result::Ok(_) => 'done'.print(),
//        Result::Err(panic_data) => {
//            assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
//        }
//    };
//     stop_prank(contract_address);
//    // issue a request times : 1, amount in wei : 19999999912312312312312322323223232323233, toss_prediction : 1
//    safe_dispatcher.issue_request(1,19999999912312312312312322323223232323233,1).unwrap();
//
    // match safe_dispatcher.finalize_request(0,11231231423423423423423231231233) {
    //    //Result::Ok(_) => panic_with_felt252('Should have panicked'),
    //    Result::Ok(_) => 'done'.print(),
    //    Result::Err(panic_data) => {
    //        assert(*panic_data.at(0) == 'Wrong number', *panic_data.at(0));

    //    }
//    };
//    //let keccak = safe_dispatcher.calculate_keccak(86419839744980627174922957242311545107819912114511241305104172346493761755852).unwrap();
//}
//

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


    let flip_safe_dispatcher = IFlipSafeDispatcher { contract_address:flip_contract_address };
    let erc20_safe_dispatcher = IERC20SafeDispatcher { contract_address:erc20_contract_address };

    flip_safe_dispatcher.owner().unwrap().print();
    flip_contract_address.print();

    let balance_of_treasury =  erc20_safe_dispatcher.balance_of(starknet::contract_address_try_from_felt252(treasury).unwrap()).unwrap();
    assert( balance_of_treasury == initialSupply, 'Balances dont match!');

    flip_safe_dispatcher.set_token_support('METH', erc20_contract_address);
    let is_supported:bool = flip_safe_dispatcher.is_token_supported('METH').unwrap();
    is_supported.print();

    let is_supported:bool = flip_safe_dispatcher.is_token_supported('ETH').unwrap();
    is_supported.print();

    let mut request_ids: Array<felt252> = ArrayTrait::new();
    let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
    let mut random_numbers = ArrayTrait::<u256>::new();
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
    
    flip_safe_dispatcher.write_fair_rng_batch(request_ids,fair_random_number_hashes);
    let req0 = flip_safe_dispatcher.get_fair_rng(0).unwrap();
    let req1 = flip_safe_dispatcher.get_fair_rng(1).unwrap();
    let req2 = flip_safe_dispatcher.get_fair_rng(2).unwrap();
    let req3 = flip_safe_dispatcher.get_fair_rng(3).unwrap();
    let req4 = flip_safe_dispatcher.get_fair_rng(4).unwrap();
    
    req0.print();
    req1.print();
    req2.print();
    req3.print();
    req4.print();
 }