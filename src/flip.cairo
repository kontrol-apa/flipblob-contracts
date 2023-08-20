use core::zeroable::Zeroable;
use array::{Span, ArrayTrait, SpanTrait};
use starknet::ContractAddress;


#[starknet::interface]
trait IFlip<TContractState> {
    fn get_next_request_id(self: @TContractState) -> felt252;
    fn get_request(self: @TContractState, request_id : felt252) -> Flip::requestMetadata;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn issue_request(ref self: TContractState, times: u256, wager_amount: u256, toss_result: u256, erc20_name: felt252);
    fn finalize_request(ref self: TContractState, requestId: felt252, rng: u256);
    fn get_request_status(self: @TContractState, request_id : felt252) -> felt252;
    fn get_last_finalized_request_id(self: @TContractState) -> felt252;
    fn calculate_keccak(self:  @TContractState, num : u256) -> u256;
    fn write_fair_rng(ref self: TContractState, request_id : felt252, fair_random_number_hash : u256);
    fn write_fair_rng_batch(ref self: TContractState, request_ids : Span<felt252>, fair_random_number_hashes : Array<u256>);
    fn get_fair_rng(self:  @TContractState, request_id : felt252) -> u256;
    fn owner(self: @TContractState) -> ContractAddress;
    fn set_flip_fee(ref self: TContractState, newFee:u256);
    fn get_flip_fee(self: @TContractState)-> u256;
    fn set_token_support(ref self: TContractState, tokenName:felt252, tokenAddr: ContractAddress);
    fn is_token_supported(self: @TContractState, tokenName:felt252) -> bool;
    fn get_token_address(self: @TContractState, tokenName:felt252) -> ContractAddress;
    fn update_treasury (ref self: TContractState, treasuryAddress: felt252);
    fn get_request_final_state(self: @TContractState, request_id : felt252) -> (felt252,u256);

}

#[starknet::interface]
trait ERC20<TContractState> {
    fn transferFrom(ref self: TContractState, sender: felt252, recipient: felt252, amount: u256);
}

#[starknet::contract]
mod Flip {
    use starknet::ContractAddress;
    use openzeppelin::access::ownable::Ownable;
    use openzeppelin::access::ownable::Ownable::{InternalImpl,OwnableImpl };
    use array::{Span, ArrayTrait, SpanTrait};
    use starknet::{get_caller_address, get_contract_address };
    use super::{ERC20Dispatcher, ERC20DispatcherTrait};
    use option::OptionTrait;
    use zeroable::Zeroable;


    #[storage]
    struct Storage {
        balance: felt252,
        next_request_id: felt252,
        last_request_id_finalized: felt252, // required for backend to pick up unfinalized requests
        requests: LegacyMap<felt252, requestMetadata>,
        requestStatus: LegacyMap<felt252, felt252>,
        request_success_count: LegacyMap<felt252, u256>,
        fair_random_numbers: LegacyMap<felt252, u256>,
        supported_erc20: LegacyMap<felt252, ContractAddress>,
        treasury_address: felt252,
        flip_fee:u256,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct requestMetadata {
        userAddress: ContractAddress,
        times: u256,
        wager_amount: u256,
        chosen_coin_face: u256,
        token : felt252
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
        issuer : felt252,
        toss_prediction : u256,
        times : u256,
        token : felt252,
        request_id : felt252
    }

    #[derive(Drop, starknet::Event)]
    struct RequestFinalized {
        request_id : felt252,
        success : bool,
        profit : u256

    }


    #[constructor]
    fn constructor(ref self: ContractState, treasuryAddress: felt252, owner_address: felt252, flipFee: u256) {
        // owner address
        let owner: ContractAddress = starknet::contract_address_try_from_felt252(owner_address).unwrap();
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        InternalImpl::initializer(ref unsafe_state,owner); // set the caller as owner
        self.next_request_id.write(1); // if request ids start from 0, it makes it super hard on the backend to track some stuff
        self.flip_fee.write(flipFee);
        self.treasury_address.write(treasuryAddress);
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn get_token_support(self: @ContractState, tokenName:felt252) -> Option<ContractAddress> {
            let tokenAddress = self.supported_erc20.read(tokenName);
            if tokenAddress.is_zero() {

                return Option::None(());
            }
            else {
                return Option::Some(tokenAddress);
            }
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
        fn get_last_finalized_request_id(self: @ContractState) -> felt252 {
            self.last_request_id_finalized.read()
        }
        fn get_request_status(self: @ContractState, request_id : felt252) -> felt252 {
            self.requestStatus.read(request_id)
        }
        fn get_request(self: @ContractState, request_id : felt252) -> requestMetadata{
            self.requests.read(request_id)
        }

        // for testing purposes
        fn calculate_keccak(self:  @ContractState, num : u256) -> u256 {
            keccak::keccak_u256s_le_inputs(array![num].span())
        }
        fn write_fair_rng(ref self: ContractState, request_id : felt252, fair_random_number_hash : u256){
            let ownable = Ownable::unsafe_new_contract_state(); 
            InternalImpl::assert_only_owner(@ownable);
            self.fair_random_numbers.write(request_id,fair_random_number_hash);
        }
        fn write_fair_rng_batch(ref self: ContractState, request_ids : Span<felt252>, fair_random_number_hashes : Array<u256>){
            assert(request_ids.len() == fair_random_number_hashes.len(),'Sizes must match');
            let ownable = Ownable::unsafe_new_contract_state(); 
            InternalImpl::assert_only_owner(@ownable);
            let mut index:usize = 0;
            loop {

                let request_id = *request_ids.at(index);
                let fair_random_number_hash = *fair_random_number_hashes.at(index);
                self.fair_random_numbers.write(request_id,fair_random_number_hash);   
                index += 1;
                if request_ids.len() == index {
                    break;
                };
            }

        }
        fn get_fair_rng(self:  @ContractState, request_id : felt252) -> u256 {
            self.fair_random_numbers.read(request_id)
        }

        fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
           let mut unsafe_state = Ownable::unsafe_new_contract_state();
           Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, new_owner);
        }

        fn issue_request(
            ref self: ContractState, times: u256, wager_amount: u256, toss_result: u256, erc20_name: felt252
        ) {
            let caller: ContractAddress = get_caller_address();
            let issuer = starknet::contract_address_to_felt252(caller);
            assert(((toss_result == 0) || (toss_result == 1)), 'Unsupported Coin Face.');
            assert (times > 0, 'Invalid amount.');

            match self.get_token_support(erc20_name) {
                Option::Some(_token_address) => {
                    ERC20Dispatcher {contract_address: _token_address}.transferFrom(issuer, self.treasury_address.read(), wager_amount * times);
                    let current_request_id: felt252 = self.next_request_id.read();
                    self.next_request_id.write(current_request_id + 1); // increment
                    self.requests.write(current_request_id, requestMetadata {userAddress:caller, times:times, wager_amount: wager_amount, chosen_coin_face: toss_result, token: erc20_name });
                    self.emit(RequestIssued { wager_amount :wager_amount, issuer :  issuer, toss_prediction : toss_result, times : times, token: erc20_name, request_id : current_request_id});
                },
                Option::None(()) => {
                    panic_with_felt252('Token is Not Supported');
                },
            }
            
        }
        fn finalize_request(ref self: ContractState, requestId: felt252, rng: u256) {
            let request = self
                .requests
                .read(requestId);
            
            let user_address  = request.userAddress ;
            let times  = request.times;
            let wager_amount  = request.wager_amount ;
            let toss_result_prediction  = request.chosen_coin_face ;
            let erc20_name  = request.token ;
            let mut profit = 0;
            let last_request_finalized = self.last_request_id_finalized.read();


            let request_status = self.requestStatus.read(requestId);
            let res = keccak::keccak_u256s_le_inputs(array![rng].span()); // returns a u256
            let fair_random_number_hash = self.fair_random_numbers.read(requestId);

            assert(res == fair_random_number_hash, 'Wrong number.');
            assert(request_status == 0, 'Request already finalized.');

            self.requestStatus.write(requestId, 1);
            self.last_request_id_finalized.write(last_request_finalized + 1);
            let mut success = false;
            let mut success_count = 0;
            let mut index  = 1;
            let mut mut_rng = rng;
            loop {
                let toss_result:u256 = mut_rng % 2;
                if toss_result == toss_result_prediction {
                    success = true;
                    success_count += 1;
                }

                if index == times {
                    break;
                }
                index += 1;
                mut_rng = mut_rng / 2;
            };

            if (success) {
                let user_address_felt252: felt252 = starknet::contract_address_to_felt252(user_address);
                profit = (wager_amount * (100 - self.flip_fee.read()) / 100) * success_count;
                match self.get_token_support(erc20_name) {
                    Option::Some(_token_address) => {
                        ERC20Dispatcher {
                        contract_address: _token_address
                        }.transferFrom(self.treasury_address.read(), user_address_felt252, (wager_amount + profit));
                        
                        self.last_request_id_finalized.write(requestId);
                        self.request_success_count.write(requestId, success_count); // modify for multiple flips
                    },
                    Option::None(()) => {
                        panic_with_felt252('Should Not Execute.');  // Should never execute this line
                    },
                }
            }
            self.emit(RequestFinalized { request_id :requestId, success : success, profit : profit });

        }

        fn set_flip_fee(ref self: ContractState, newFee:u256) {
            let ownable = Ownable::unsafe_new_contract_state(); 
            InternalImpl::assert_only_owner(@ownable);
            assert( newFee <= 100, 'Fee cant be higher than 100');
            self.flip_fee.write(newFee);
        }

        fn get_flip_fee(self: @ContractState) -> u256 {
            self.flip_fee.read()
        }

        fn set_token_support(ref self: ContractState, tokenName:felt252, tokenAddr: ContractAddress) {
            let ownable = Ownable::unsafe_new_contract_state(); 
            InternalImpl::assert_only_owner(@ownable);
            self.supported_erc20.write(tokenName, tokenAddr);
        }

        fn is_token_supported(self: @ContractState, tokenName:felt252) -> bool {
            let tokenAddress = self.supported_erc20.read(tokenName);
            if tokenAddress.is_zero() {

                return false;
            }
            else {
                return true;
            }
        }

        fn get_token_address(self: @ContractState, tokenName:felt252) -> ContractAddress {
            self.supported_erc20.read(tokenName)
        }


        fn update_treasury (ref self: ContractState, treasuryAddress: felt252) {
            let ownable = Ownable::unsafe_new_contract_state(); 
            InternalImpl::assert_only_owner(@ownable);
            assert(treasuryAddress.is_non_zero(), 'Cant use 0 address');
            self.treasury_address.write(treasuryAddress);
        }

        fn get_request_final_state(self: @ContractState, request_id : felt252) -> (felt252,u256) {
            (self.requestStatus.read(request_id), self.request_success_count.read(request_id))
        }
    }
}


