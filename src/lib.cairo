
//use core::traits::Into;
use array::{Span, ArrayTrait, SpanTrait};
use starknet::ContractAddress;
const WETH_ADDRESS: felt252 = 0x00d0e183745e9dae3e4e78a8ffedcce0903fc4900beace4e0abf192d4c202da3;
//const x : ContractAddress =  starknet::contract_address_const::<0x00d0e183745e9dae3e4e78a8ffedcce0903fc4900beace4e0abf192d4c202da3>();
#[starknet::interface]
trait IFlip<TContractState> {
    fn get_next_request_id(self: @TContractState) -> felt252;
    fn get_request(self: @TContractState, request_id : felt252) -> (ContractAddress, u256, u256, u256);
    //fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn issue_request(ref self: TContractState, times: u256, wager_amount: u256, toss_result: u256);
    fn finalize_request(ref self: TContractState, requestId: felt252, rng: u256);
    fn get_request_status(self: @TContractState, request_id : felt252) -> felt252;
    fn get_last_finalized_request_id(self: @TContractState) -> felt252;
    fn calculate_keccak(self:  @TContractState, num : u256) -> u256;
    fn write_fair_rng(ref self: TContractState, request_id : felt252, fair_random_number_hash : u256);
    fn write_fair_rng_batch(ref self: TContractState, request_ids : Array<felt252>, fair_random_number_hashes : Array<u256>);
    fn get_fair_rng(self:  @TContractState, request_id : felt252) -> u256;
    
    fn owner(self: @TContractState) -> ContractAddress;
}

#[starknet::interface]
trait IWETH<TContractState> {
    fn transferFrom(ref self: TContractState, sender: felt252, recipient: felt252, amount: u256);
}

#[starknet::contract]
mod Flip {
    use starknet::ContractAddress;
    //use serde::Serde;
    //use starknet::Felt252TryIntoContractAddress;
    use openzeppelin::access::ownable::Ownable::InternalImpl;
    use openzeppelin::access::ownable::Ownable;
    use openzeppelin::access::ownable::Ownable::OwnableImpl;
    use array::{Span, ArrayTrait, SpanTrait};
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    //use starknet::syscalls::keccak_syscall;
    use super::{IWETHDispatcher, IWETHDispatcherTrait};
    //const x : felt252 =  starknet::contract_address_const::<0x00d0e183745e9dae3e4e78a8ffedcce0903fc4900beace4e0abf192d4c202da3>();
    const treasury_addy: felt252 = 0x05fd781a9fb5a87e7eff097d25860d6ab5d5662235b2e49189565c822f4c6fc8;

    #[storage]
    struct Storage {
        balance: felt252,
        next_request_id: felt252,
        last_request_id_finalized: felt252, // required for backend to pick up unfinalized requests
        // requestid -> address, times, wager amount, toss result
        // felt252 -> tupple (replace with struct)
        requests: LegacyMap<felt252, (ContractAddress, u256, u256, u256)>,
        requestStatus: LegacyMap<felt252, felt252>,
        fair_random_numbers: LegacyMap<felt252, u256>,
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
        times : u256

    }

    #[derive(Drop, starknet::Event)]
    struct RequestFinalized {
        request_id : felt252,
        success : bool

    }


    #[constructor]
    fn constructor(ref self: ContractState) {
        // owner address
        let caller: ContractAddress = get_caller_address();
        let mut unsafe_state = Ownable::unsafe_new_contract_state();
        InternalImpl::initializer(ref unsafe_state,caller); // set the caller as owner
        self.next_request_id.write(1); // if request ids start from 0, it makes it super hard on the backend to track some stuff
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
        fn get_request(self: @ContractState, request_id : felt252) -> (ContractAddress, u256, u256, u256){
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
        fn write_fair_rng_batch(ref self: ContractState, request_ids : Array<felt252>, fair_random_number_hashes : Array<u256>){
            assert(request_ids.len() == fair_random_number_hashes.len(),'Sizes must match');

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

        //fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        //    let mut unsafe_state = Ownable::unsafe_new_contract_state();
        //    Ownable::OwnableImpl::transfer_ownership(ref unsafe_state, new_owner);
        //}
        fn issue_request(
            ref self: ContractState, times: u256, wager_amount: u256, toss_result: u256
        ) {
            let caller: ContractAddress = get_caller_address();
            let issuer = starknet::contract_address_to_felt252(caller);
            let WETH: ContractAddress = starknet::contract_address_const::<0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36>();
            IWETHDispatcher {contract_address: WETH}.transferFrom(issuer, treasury_addy, wager_amount);
            let current_request_id: felt252 = self.next_request_id.read();
            self.next_request_id.write(current_request_id + 1); // increment
            self.requests.write(current_request_id, (caller, times, wager_amount, toss_result));
            self.emit(RequestIssued { wager_amount :wager_amount, issuer :  issuer, toss_prediction : toss_result, times : times });
        }
        fn finalize_request(ref self: ContractState, requestId: felt252, rng: u256) {
            let (player_address, times, wager_amount, toss_result_prediction) = self
                .requests
                .read(requestId);
            let request_status = self.requestStatus.read(requestId);
            let res = keccak::keccak_u256s_le_inputs(array![rng].span()); // returns a u256
            let fair_random_number_hash = self.fair_random_numbers.read(requestId);
            assert(res == fair_random_number_hash, 'Wrong number');
            assert(request_status == 0, 'Request already finalized');
            self.requestStatus.write(requestId, 1);
            let toss_result = rng % 2;
            let success = toss_result == toss_result_prediction;
            if (success) {
                let x = false;
                let WETH: ContractAddress = starknet::contract_address_const::<0x034e31357d1c3693bda06d04bf4c51557514ECed5A8e9973bDb772f7fB978B36>();
                let x: felt252 = starknet::contract_address_to_felt252(player_address);
                IWETHDispatcher {
                    contract_address: WETH
                }.transferFrom(treasury_addy, x, (wager_amount + (wager_amount * 95 / 100)));
            }
            self.last_request_id_finalized.write(requestId);
            self.emit(RequestFinalized { request_id :requestId, success : success  });
            
        }
    }
}

#[starknet::contract]
mod ERC20 {
    use integer::BoundedInt;
    use openzeppelin::token::erc20::interface::IERC20;
    use openzeppelin::token::erc20::interface::IERC20CamelOnly;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _name: felt252,
        _symbol: felt252,
        _total_supply: u256,
        _balances: LegacyMap<ContractAddress, u256>,
        _allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState
    ) {
        self.initializer('MOCK_WETH', 'MWETH');
        //self._mint(recipient, initial_supply);
    }

    //
    // External
    //
    #[external(v0)]
    #[generate_trait]
    impl UserFunctions of UserFunctionsTrait {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self._mint(recipient, amount);
        }
    }



    #[external(v0)]
    impl ERC20Impl of IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self._name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self._symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            18
        }

        fn total_supply(self: @ContractState) -> u256 {
            self._total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self._balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self._allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            let caller = get_caller_address();
            self._spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, amount);
            true
        }
    }

    #[external(v0)]
    impl ERC20CamelOnlyImpl of IERC20CamelOnly<ContractState> {
        fn totalSupply(self: @ContractState) -> u256 {
            ERC20Impl::total_supply(self)
        }

        fn balanceOf(self: @ContractState, account: ContractAddress) -> u256 {
            ERC20Impl::balance_of(self, account)
        }

        fn transferFrom(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) -> bool {
            ERC20Impl::transfer_from(ref self, sender, recipient, amount)
        }
    }

    #[external(v0)]
    fn increase_allowance(
        ref self: ContractState, spender: ContractAddress, added_value: u256
    ) -> bool {
        self._increase_allowance(spender, added_value)
    }

    #[external(v0)]
    fn increaseAllowance(
        ref self: ContractState, spender: ContractAddress, addedValue: u256
    ) -> bool {
        increase_allowance(ref self, spender, addedValue)
    }

    #[external(v0)]
    fn decrease_allowance(
        ref self: ContractState, spender: ContractAddress, subtracted_value: u256
    ) -> bool {
        self._decrease_allowance(spender, subtracted_value)
    }

    #[external(v0)]
    fn decreaseAllowance(
        ref self: ContractState, spender: ContractAddress, subtractedValue: u256
    ) -> bool {
        decrease_allowance(ref self, spender, subtractedValue)
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(ref self: ContractState, name_: felt252, symbol_: felt252) {
            self._name.write(name_);
            self._symbol.write(symbol_);
        }

        fn _increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self._approve(caller, spender, self._allowances.read((caller, spender)) + added_value);
            true
        }

        fn _decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) -> bool {
            let caller = get_caller_address();
            self
                ._approve(
                    caller, spender, self._allowances.read((caller, spender)) - subtracted_value
                );
            true
        }

        fn _mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(!recipient.is_zero(), 'ERC20: mint to 0');
            self._total_supply.write(self._total_supply.read() + amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: Zeroable::zero(), to: recipient, value: amount });
        }

        fn _burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            assert(!account.is_zero(), 'ERC20: burn from 0');
            self._total_supply.write(self._total_supply.read() - amount);
            self._balances.write(account, self._balances.read(account) - amount);
            self.emit(Transfer { from: account, to: Zeroable::zero(), value: amount });
        }

        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'ERC20: approve from 0');
            assert(!spender.is_zero(), 'ERC20: approve to 0');
            self._allowances.write((owner, spender), amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            assert(!sender.is_zero(), 'ERC20: transfer from 0');
            assert(!recipient.is_zero(), 'ERC20: transfer to 0');
            self._balances.write(sender, self._balances.read(sender) - amount);
            self._balances.write(recipient, self._balances.read(recipient) + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn _spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self._allowances.read((owner, spender));
            if current_allowance != BoundedInt::max() {
                self._approve(owner, spender, current_allowance - amount);
            }
        }
    }
}

