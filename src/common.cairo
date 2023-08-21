// common.cairo

use starknet::{ContractAddress, contract_address_try_from_felt252};
use option::OptionTrait;

// mock addresses

fn admin() -> ContractAddress {
    contract_address_try_from_felt252('admin').unwrap()
}

fn badguy() -> ContractAddress {
    contract_address_try_from_felt252('bad guy').unwrap()
}

fn user_no_funds() -> ContractAddress {
    contract_address_try_from_felt252('user no funds').unwrap()
}

fn user() -> ContractAddress {
    contract_address_try_from_felt252('user whale').unwrap()
}

fn treasury() -> ContractAddress {
    contract_address_try_from_felt252('treasury').unwrap()
}
