const HEAD: felt252 = 1;
const TAIL: felt252 = 0;
const INVALID: felt252 = 2;


mod tests {
    use array::{Span, ArrayTrait, SpanTrait, ArrayTCloneImpl};
    use result::ResultTrait;
    use option::{Option, OptionTrait};
    use traits::TryInto;
    use traits::Into;
    use starknet::ContractAddress;
    use starknet::Felt252TryIntoContractAddress;
    use clone::Clone;
    use flipblob::flip::IFlipSafeDispatcher;
    use flipblob::flip::IFlipSafeDispatcherTrait;
    use openzeppelin::token::erc20::interface::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

    use starknet::get_caller_address;
    use flipblob::common;
    use snforge_std::{declare, ContractClassTrait, start_prank, stop_prank, PrintTrait};

    const MAX_BET_AMOUNT: u256 = 10;

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
                Option::None(_) => {
                    break erc20_addresses.clone();
                }
            };
        }
    }

    fn deploy_flip_and_mocketh() -> (ContractAddress, ContractAddress) {
        let mut calldata = ArrayTrait::new();
        let flipFee: u256 = 5;
        let flipFeeLow = flipFee.low.into();
        let flipFeeHigh = flipFee.high.into();

        calldata.append(starknet::contract_address_to_felt252(common::treasury()));
        calldata.append(starknet::contract_address_to_felt252(common::admin()));
        calldata.append(flipFeeLow);
        calldata.append(flipFeeHigh);
        calldata.append(starknet::contract_address_to_felt252(common::finalizer()));

        let flip_contract_address = deploy_contract('Flip', calldata);

        let mut calldata = ArrayTrait::new();
        let initialSupply: u256 = 100000000000000000000;
        let initialSupplyLow = initialSupply.low.into();
        let initialSupplyHigh = initialSupply.high.into();

        calldata.append('MOCK_ETH');
        calldata.append('METH');
        calldata.append(initialSupplyLow);
        calldata.append(initialSupplyHigh);
        calldata.append(starknet::contract_address_to_felt252(common::treasury()));

        let meth_contract_address = deploy_contract('ERC20', calldata);
        let meth_safe_dispatcher = ERC20ABIDispatcher { contract_address: meth_contract_address };
        let balance_of_treasury = meth_safe_dispatcher.balance_of(common::treasury());
        assert(balance_of_treasury == initialSupply, 'Balances dont match!');

        (flip_contract_address, meth_contract_address)
    }

    fn deploy_flip_and_mocketh_usdc() -> (ContractAddress, ContractAddress, ContractAddress) {
        let mut calldata = ArrayTrait::new();
        let flipFee: u256 = 5;
        let flipFeeLow = flipFee.low.into();
        let flipFeeHigh = flipFee.high.into();

        calldata.append(starknet::contract_address_to_felt252(common::treasury()));
        calldata.append(starknet::contract_address_to_felt252(common::admin()));
        calldata.append(flipFeeLow);
        calldata.append(flipFeeHigh);
        calldata.append(starknet::contract_address_to_felt252(common::finalizer()));

        let flip_contract_address = deploy_contract('Flip', calldata);
        let mut calldatas: Array<Array<felt252>> = ArrayTrait::new();

        let mut calldata = ArrayTrait::new();
        let initialSupply: u256 = 100000000000000000000;
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

        let addresses: Array<ContractAddress> = deploy_multiple_contracts('ERC20', calldatas);
        let usdc_safe_dispatcher = ERC20ABIDispatcher { contract_address: *addresses.at(0) };
        let balance_of_treasury = usdc_safe_dispatcher.balance_of(common::treasury());
        assert(balance_of_treasury == initialSupply, 'Balances dont match!');

        (flip_contract_address, *addresses.at(1), *addresses.at(0))
    }

    fn set_token_support(
        ref flip_safe_dispatcher: IFlipSafeDispatcher,
        flip_contract_address: @ContractAddress,
        erc20_contract_address: @ContractAddress,
        max_bet_amount: u256,
        token_name: felt252
    ) {
        start_prank(*flip_contract_address, common::admin()); // MOCK ADMIN TO ADD COIN SUPPORT
        flip_safe_dispatcher.set_token_support(token_name, *erc20_contract_address, max_bet_amount);
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

    fn approve_and_mint(
        ref erc20_safe_dispatcher: ERC20ABIDispatcher,
        flip_contract_address: @ContractAddress,
        erc20_contract_address: @ContractAddress,
        amount: u256
    ) {
        start_prank(*erc20_contract_address, common::user()); // MOCK USER TO FLIP
        erc20_safe_dispatcher.approve(*flip_contract_address, amount);
        erc20_safe_dispatcher.mint(common::user(), amount);
        stop_prank(*erc20_contract_address);

        start_prank(
            *erc20_contract_address, common::treasury()
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
        finalizer:ContractAddress,
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
    fn test_single_erc20() {
        let (flip_contract_address, meth_contract_address) = deploy_flip_and_mocketh();
        let mut flip_safe_dispatcher = IFlipSafeDispatcher {
            contract_address: flip_contract_address
        };
        let mut meth_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: meth_contract_address
        };

        let max_bet_amount_meth: u256 = 100000000000000000;
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            max_bet_amount_meth,
            'METH'
        );

        let mut request_ids: Array<felt252> = ArrayTrait::new();
        let mut random_numbers = ArrayTrait::<u256>::new();
        prepare_rng(ref request_ids, ref random_numbers);

        approve_and_mint(
            ref meth_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            1000000000000000000
        );

        let index = 0;
        let bet = 1000000;
        let pre_bet_balance = meth_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(1, bet, super::HEAD, 'METH');
        stop_prank(flip_contract_address);

        let pre_balance = meth_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet), 'Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::treasury(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Only Finalizer'
        );

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );

        let post_balance = meth_safe_dispatcher.balance_of(common::user());
        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');

        assert(
            (post_balance
                - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet, success_count),
            'Balances dont match!'
        );

        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        match flip_safe_dispatcher.issue_request(1, bet, super::INVALID, 'METH') {
            Result::Ok(_) => 'Passed.'.print(),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Unsupported Coin Face.', *panic_data.at(0));
            }
        }
        stop_prank(flip_contract_address);
    }

    #[test]
    fn test_double_erc20() {
        let (flip_contract_address, meth_contract_address, usdc_contract_address) =
            deploy_flip_and_mocketh_usdc();
        let mut flip_safe_dispatcher = IFlipSafeDispatcher {
            contract_address: flip_contract_address
        };
        let mut meth_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: meth_contract_address
        };
        let mut usdc_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: usdc_contract_address
        };
        let max_bet_amount_meth = 100000000000000000;
        let max_bet_amount_usdc = 100000000000000000000;

        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            max_bet_amount_meth,
            'METH'
        );
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            max_bet_amount_usdc,
            'USDC'
        );

        let mut request_ids: Array<felt252> = ArrayTrait::new();
        let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
        let mut random_numbers = ArrayTrait::<u256>::new();
        prepare_rng(ref request_ids, ref random_numbers);

        approve_and_mint(
            ref meth_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            100000000000000000000
        );
        approve_and_mint(
            ref usdc_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            10000000000000000000
        );

        let mut index = 0;
        let mut bet = 1000000;
        let pre_bet_balance = meth_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(1, bet, super::HEAD, 'METH');
        stop_prank(flip_contract_address);

        let pre_balance = meth_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet), 'Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );

        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');

        let post_balance = meth_safe_dispatcher.balance_of(common::user());
        assert(
            (post_balance
                - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet, success_count),
            'Balances dont match!'
        );

        index = index + 1;
        bet = 11000000;
        let pre_bet_balance = usdc_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(1, bet, super::TAIL, 'USDC');
        stop_prank(flip_contract_address);

        let pre_balance = usdc_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet), 'Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );

        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');

        let post_balance = usdc_safe_dispatcher.balance_of(common::user());
        assert(
            (post_balance
                - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet, success_count),
            'Balances dont match!'
        );

        bet = 11000000;
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        match flip_safe_dispatcher.issue_request(1, bet, super::INVALID, 'METH') {
            Result::Ok(_) => 'Passed.'.print(),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Unsupported Coin Face.', *panic_data.at(0));
            }
        }

        match flip_safe_dispatcher.issue_request(1, bet, super::HEAD, 'USDC') {
            Result::Ok(_) => 'Passed.'.print(),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
            }
        }
        stop_prank(flip_contract_address);

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Request already finalized.'
        );

        index = index + 1;
        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );
    }
    #[test]
    fn test_multi_bet() {
        let (flip_contract_address, meth_contract_address, usdc_contract_address) =
            deploy_flip_and_mocketh_usdc();
        let mut flip_safe_dispatcher = IFlipSafeDispatcher {
            contract_address: flip_contract_address
        };
        let mut meth_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: meth_contract_address
        };
        let mut usdc_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: usdc_contract_address
        };
        let max_bet_amount_meth = 100000000000000000;
        let max_bet_amount_usdc = 100000000000000000000;
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            max_bet_amount_meth,
            'METH'
        );
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            max_bet_amount_usdc,
            'USDC'
        );

        let mut request_ids: Array<felt252> = ArrayTrait::new();
        let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
        let mut random_numbers = ArrayTrait::<u256>::new();
        prepare_rng(ref request_ids, ref random_numbers);

        approve_and_mint(
            ref meth_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            10000000000000000000000
        );
        approve_and_mint(
            ref usdc_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            1000000000000000000000
        );

        let mut index = 0;
        let mut bet = 10000000;
        let mut times = 10;
        let mut pre_bet_balance = meth_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(times, bet, super::TAIL, 'METH');
        stop_prank(flip_contract_address);

        let mut pre_balance = meth_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet * times), 'Issue Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );

        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');
        assert(success_count <= times, 'Count greater than the amount');
        let mut post_balance = meth_safe_dispatcher.balance_of(common::user());
        assert(
            (post_balance
                - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet, success_count),
            'Balances dont match!'
        );

        bet = 555555;
        times = 3;
        index = index + 1;
        pre_bet_balance = usdc_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'USDC');
        stop_prank(flip_contract_address);

        pre_balance = usdc_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet * times), 'Issue Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );
        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');
        assert(success_count <= times, 'Count greater than the amount');
        post_balance = usdc_safe_dispatcher.balance_of(common::user());
        assert(
            (post_balance
                - pre_balance) == calculate_payout(ref flip_safe_dispatcher, bet, success_count),
            'Balances dont match!'
        );

        times = 11;
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        match flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'METH') {
            Result::Ok(_) => 'Passed.'.print(),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Invalid amount.', *panic_data.at(0));
            }
        }
        stop_prank(flip_contract_address);
    }

    #[test]
    fn test_max_wager() {
        let (flip_contract_address, meth_contract_address, usdc_contract_address) =
            deploy_flip_and_mocketh_usdc();
        let mut flip_safe_dispatcher = IFlipSafeDispatcher {
            contract_address: flip_contract_address
        };
        let mut meth_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: meth_contract_address
        };
        let mut usdc_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: usdc_contract_address
        };
        let max_bet_amount_meth = 100000000000000000;
        let max_bet_amount_usdc = 10000000000000000000;
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            max_bet_amount_meth,
            'METH'
        );
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            max_bet_amount_usdc,
            'USDC'
        );

        let mut request_ids: Array<felt252> = ArrayTrait::new();
        let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
        let mut random_numbers = ArrayTrait::<u256>::new();
        prepare_rng(ref request_ids, ref random_numbers);

        approve_and_mint(
            ref meth_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            10000000000000000000000000000
        );
        approve_and_mint(
            ref usdc_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            1000000000000000000000000000
        );
        let mut index = 0;
        let mut bet = max_bet_amount_meth;
        let mut times = 1;
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        match flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'METH') {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Wager too high', *panic_data.at(0));
            }
        }
        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count == 0, 'TX musn`t not be finalized!');
        assert(flip_safe_dispatcher.get_next_request_id().unwrap() == 1, 'No TX has been made');


        let mut bet = max_bet_amount_usdc;
        let mut times = 10;
         match flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'USDC') {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Wager too high', *panic_data.at(0));
            }
        }
        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count == 0, 'TX musn`t be finalized!');
        assert(flip_safe_dispatcher.get_next_request_id().unwrap() == 1, 'No TX has been made');

        
        let mut bet = 0;
        let mut times = 10;
         match flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'USDC') {
            Result::Ok(_) => 'Done'.print(),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
            }
        }
        
        assert(flip_safe_dispatcher.get_next_request_id().unwrap() == 2, 'A TX has been made');
        stop_prank(flip_contract_address);

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::finalizer(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Success'
        );

        let success_count = flip_safe_dispatcher
            .get_request_status(*request_ids.at(index))
            .unwrap()
            .into();
        assert(success_count != 0, 'TX must be finalized!');

        let mut times = 11;
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        match flip_safe_dispatcher.issue_request(times, bet, super::HEAD, 'METH') {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Invalid amount.', *panic_data.at(0));
            }
        }
        stop_prank(flip_contract_address);
    }

    #[test]
    fn test_ownership() {
        let (flip_contract_address, meth_contract_address, usdc_contract_address) =
            deploy_flip_and_mocketh_usdc();
        let mut flip_safe_dispatcher = IFlipSafeDispatcher {
            contract_address: flip_contract_address
        };
        let mut meth_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: meth_contract_address
        };
        let mut usdc_safe_dispatcher = ERC20ABIDispatcher {
            contract_address: usdc_contract_address
        };
        let max_bet_amount_meth = 100000000000000000;
        let max_bet_amount_usdc = 10000000000000000000;
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            max_bet_amount_meth,
            'METH'
        );
        set_token_support(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            max_bet_amount_usdc,
            'USDC'
        );

        let mut request_ids: Array<felt252> = ArrayTrait::new();
        let mut fair_random_number_hashes: Array<u256> = ArrayTrait::new();
        let mut random_numbers = ArrayTrait::<u256>::new();
        prepare_rng(ref request_ids, ref random_numbers);

        approve_and_mint(
            ref meth_safe_dispatcher,
            @flip_contract_address,
            @meth_contract_address,
            10000000000000000000000000000
        );
        approve_and_mint(
            ref usdc_safe_dispatcher,
            @flip_contract_address,
            @usdc_contract_address,
            1000000000000000000000000000
        );

        start_prank(flip_contract_address, common::badguy()); // MOCK ADMIN TO ADD COIN SUPPORT
        match flip_safe_dispatcher.set_token_support('SOL', meth_contract_address, 100) {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
            }
        }

        match flip_safe_dispatcher.set_max_bet('SOL', 100000) {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
            }
        }

        match flip_safe_dispatcher.update_treasury('badguy') {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
            }
        }

        match flip_safe_dispatcher.set_finalizer(common::badguy()) {
            Result::Ok(_) => panic_with_felt252('Should\'ve Panicked'),
            Result::Err(panic_data) => {
                (*panic_data.at(0)).print();
                assert(*panic_data.at(0) == 'Caller is not the owner', *panic_data.at(0));
            }
        }
        stop_prank(flip_contract_address);

        let index = 0;
        let bet = 1000000;
        let pre_bet_balance = meth_safe_dispatcher.balance_of(common::user());
        start_prank(flip_contract_address, common::user()); // MOCK USER TO FLIP
        flip_safe_dispatcher.issue_request(1, bet, super::HEAD, 'METH');

        let pre_balance = meth_safe_dispatcher.balance_of(common::user());
        assert((pre_bet_balance - pre_balance) == (bet), 'Balances dont match!');

        finalize_request(
            ref flip_safe_dispatcher,
            @flip_contract_address,
            common::treasury(),
            *request_ids.at(index),
            *random_numbers.at(index),
            'Only Finalizer'
        );

        stop_prank(flip_contract_address);

        
    }
}

