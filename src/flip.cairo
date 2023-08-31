use core::zeroable::Zeroable;
use array::{Span, ArrayTrait, SpanTrait};
use starknet::ContractAddress;


#[starknet::interface]
trait IFlip<TContractState> {
    fn get_next_request_id(self: @TContractState) -> felt252;
    fn get_request(self: @TContractState, request_id: felt252) -> Flip::requestMetadata;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn issue_request(
        ref self: TContractState,
        times: u256,
        wager_amount: u256,
        toss_result: felt252,
        erc20_name: felt252
    );
    fn finalize_request(ref self: TContractState, requestId: felt252, rng: u256);
    fn get_request_status(self: @TContractState, request_id: felt252) -> u256;
    fn owner(self: @TContractState) -> ContractAddress;
    fn set_flip_fee(ref self: TContractState, newFee: u256);
    fn get_flip_fee(self: @TContractState) -> u256;
    fn set_token_support(
        ref self: TContractState,
        tokenName: felt252,
        tokenAddress: ContractAddress,
        maxBetable: u256
    );
    fn is_token_supported(self: @TContractState, tokenName: felt252) -> bool;
    fn get_token_address(self: @TContractState, tokenName: felt252) -> ContractAddress;
    fn update_treasury(ref self: TContractState, treasuryAddress: felt252);
    fn set_max_bet(ref self: TContractState, tokenName: felt252, maxBetable: u256);
    fn set_finalizer(ref self: TContractState, finalizer: ContractAddress);
    fn get_finalizer(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
trait ERC20<TContractState> {
    fn transferFrom(ref self: TContractState, sender: felt252, recipient: felt252, amount: u256);
    fn balance_of(self: @TContractState, account: felt252) -> u256;
}

#[starknet::contract]
mod Flip {
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::Ownable;
    use openzeppelin::access::ownable::Ownable::{InternalImpl, OwnableImpl};
    use array::{Span, ArrayTrait, SpanTrait};
    use starknet::{get_caller_address, get_contract_address};
    use super::{ERC20Dispatcher, ERC20DispatcherTrait};
    use option::OptionTrait;
    use zeroable::Zeroable;
    use traits::Into;

    const MAX_BET_AMOUNT: u256 = 10;

    #[storage]
    struct Storage {
        next_request_id: felt252,
        requests: LegacyMap<felt252, requestMetadata>,
        requestStatus: LegacyMap<felt252, u256>,
        supported_erc20: LegacyMap<felt252, tokenMetadata>,
        treasury_address: felt252,
        flip_fee: u256,
        finalizer:ContractAddress
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct requestMetadata {
        userAddress: ContractAddress,
        times: u256,
        wager_amount: u256,
        chosen_coin_face: felt252,
        token: felt252
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct tokenMetadata {
        tokenAddress: ContractAddress,
        maxBetable: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        RequestIssued: RequestIssued,
        RequestFinalized: RequestFinalized
    }

    #[derive(Drop, starknet::Event)]
    struct RequestIssued {
        wager_amount: u256,
        issuer: felt252,
        toss_prediction: felt252,
        times: u256,
        token: felt252,
        request_id: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct RequestFinalized {
        request_id: felt252,
        profit: u256
    }


    #[constructor]
    fn constructor(
        ref self: ContractState, treasuryAddress: felt252, owner_address: felt252, flipFee: u256, finalizer:ContractAddress
    ) {
        // owner address
        let owner: ContractAddress = starknet::contract_address_try_from_felt252(owner_address)
            .unwrap();
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        InternalImpl::initializer(ref unsafe_state, owner); // set the caller as owner
        self
            .next_request_id
            .write(
                1
            ); // if request ids start from 0, it makes it super hard on the backend to track some stuff
        self.flip_fee.write(flipFee);
        self.treasury_address.write(treasuryAddress);
        self.finalizer.write(finalizer);
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn get_token_support(self: @ContractState, tokenName: felt252) -> Option<tokenMetadata> {
            let tokenMetadata = self.supported_erc20.read(tokenName);
            if tokenMetadata.tokenAddress.is_zero() {
                return Option::None(());
            } else {
                return Option::Some(tokenMetadata);
            }
        }

        #[inline(always)]
        fn is_finalizer(self: @ContractState) -> bool {
            self.finalizer.read() == get_caller_address()
        }
    }

    #[external(v0)]
    impl FlipImpl of super::IFlip<ContractState> {
        fn owner(self: @ContractState) -> ContractAddress {
            let unsafe_state = Ownable::unsafe_new_contract_state();
            OwnableImpl::owner(@unsafe_state)
        }

        fn get_next_request_id(self: @ContractState) -> felt252 {
            self.next_request_id.read()
        }
        fn get_request_status(self: @ContractState, request_id: felt252) -> u256 {
            self.requestStatus.read(request_id)
        }
        fn get_request(self: @ContractState, request_id: felt252) -> requestMetadata {
            self.requests.read(request_id)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
            let mut unsafe_state = Ownable::unsafe_new_contract_state();
            Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, new_owner);
        }

        fn issue_request(
            ref self: ContractState,
            times: u256,
            wager_amount: u256,
            toss_result: felt252,
            erc20_name: felt252
        ) {
            let caller: ContractAddress = get_caller_address();
            let issuer = starknet::contract_address_to_felt252(caller);
            assert(((toss_result == 0) || (toss_result == 1)), 'Unsupported Coin Face.');
            assert((times > 0) && (times <= MAX_BET_AMOUNT), 'Invalid amount.');
            match self.get_token_support(erc20_name) {
                Option::Some(token_metadata) => {
                    assert(token_metadata.maxBetable > wager_amount, 'Wager too high');

                    let treasuryBalance = ERC20Dispatcher {
                        contract_address: token_metadata.tokenAddress
                    }
                        .balance_of(self.treasury_address.read());

                    assert(treasuryBalance >= wager_amount * times, 'Treasury cant accept the bet');

                    ERC20Dispatcher { contract_address: token_metadata.tokenAddress }
                        .transferFrom(issuer, self.treasury_address.read(), wager_amount * times);
                    let current_request_id: felt252 = self.next_request_id.read();
                    self.next_request_id.write(current_request_id + 1); // increment
                    self
                        .requests
                        .write(
                            current_request_id,
                            requestMetadata {
                                userAddress: caller,
                                times: times,
                                wager_amount: wager_amount,
                                chosen_coin_face: toss_result,
                                token: erc20_name
                            }
                        );
                    self
                        .emit(
                            RequestIssued {
                                wager_amount: wager_amount,
                                issuer: issuer,
                                toss_prediction: toss_result,
                                times: times,
                                token: erc20_name,
                                request_id: current_request_id
                            }
                        );
                },
                Option::None(()) => {
                    panic_with_felt252('Token is Not Supported');
                },
            }
        }
        fn finalize_request(ref self: ContractState, requestId: felt252, rng: u256) {
            let request = self.requests.read(requestId);
            let user_address = request.userAddress;
            let times = request.times;
            let wager_amount = request.wager_amount;
            let toss_result_prediction = request.chosen_coin_face;
            let erc20_name = request.token;

            let user_address_felt252: felt252 = starknet::contract_address_to_felt252(user_address);
            let request_status = self.requestStatus.read(requestId);

            assert(self.is_finalizer() == true, 'Only Finalizer');
            assert(request_status == 0, 'Request already finalized.');

            let mut profit = 0;
            let mut success_count = 0;
            let mut index = 1;
            let mut seed = rng;
            loop {
                let toss_result: u256 = seed % 2;
                if toss_result == toss_result_prediction.into() {
                    success_count += 1;
                }

                if index == times {
                    break;
                }
                index += 1;
                seed = keccak::keccak_u256s_le_inputs(array![seed].span()); // returns a u256;
            };
            if (success_count > 0) {
                self.requestStatus.write(requestId, success_count); // 0 respresents unfinalized wager, anything above 0 and below 11 is a finalized wager
                profit = (wager_amount * (100 - self.flip_fee.read()) / 100) * success_count;
                match self.get_token_support(erc20_name) {
                    Option::Some(token_metadata) => {
                        ERC20Dispatcher { contract_address: token_metadata.tokenAddress }
                            .transferFrom(
                                self.treasury_address.read(),
                                user_address_felt252,
                                (wager_amount * success_count + profit)
                            );
                    },
                    Option::None(()) => {
                        panic_with_felt252('Should Not Execute.'); // Should never execute this line
                    },
                }
            }
            else {
                self.requestStatus.write(requestId, MAX_BET_AMOUNT + 1); // In case of fail write 11, which represents invalid amount
            }
            self.emit(RequestFinalized { request_id: requestId, profit: profit });
        }

        fn set_flip_fee(ref self: ContractState, newFee: u256) {
            let ownable = Ownable::unsafe_new_contract_state();
            InternalImpl::assert_only_owner(@ownable);
            assert(newFee <= 100, 'Fee cant be higher than 100');
            self.flip_fee.write(newFee);
        }

        fn get_flip_fee(self: @ContractState) -> u256 {
            self.flip_fee.read()
        }

        fn set_token_support(
            ref self: ContractState,
            tokenName: felt252,
            tokenAddress: ContractAddress,
            maxBetable: u256
        ) {
            let ownable = Ownable::unsafe_new_contract_state();
            InternalImpl::assert_only_owner(@ownable);
            self.supported_erc20.write(tokenName, tokenMetadata { tokenAddress, maxBetable });
        }

        fn set_max_bet(ref self: ContractState, tokenName: felt252, maxBetable: u256) {
            let ownable = Ownable::unsafe_new_contract_state();
            InternalImpl::assert_only_owner(@ownable);
            let mut tokenMetadata = self.supported_erc20.read(tokenName);
            tokenMetadata.maxBetable = maxBetable;
            self.supported_erc20.write(tokenName, tokenMetadata);
        }

        fn is_token_supported(self: @ContractState, tokenName: felt252) -> bool {
            let tokenMetadata = self.supported_erc20.read(tokenName);
            if tokenMetadata.tokenAddress.is_zero() {
                return false;
            } else {
                return true;
            }
        }

        fn get_token_address(self: @ContractState, tokenName: felt252) -> ContractAddress {
            self.supported_erc20.read(tokenName).tokenAddress
        }


        fn update_treasury(ref self: ContractState, treasuryAddress: felt252) {
            let ownable = Ownable::unsafe_new_contract_state();
            InternalImpl::assert_only_owner(@ownable);
            assert(treasuryAddress.is_non_zero(), 'Cant use 0 address');
            self.treasury_address.write(treasuryAddress);
        }

        fn set_finalizer(ref self: ContractState, finalizer: ContractAddress) {
            let ownable = Ownable::unsafe_new_contract_state();
            InternalImpl::assert_only_owner(@ownable);
            self.finalizer.write(finalizer);
        }

        fn get_finalizer(self: @ContractState) ->  ContractAddress {
            self.finalizer.read()
        }

    }
}

