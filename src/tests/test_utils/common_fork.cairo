// common.cairo

use starknet::contract_address_const;
use starknet::ContractAddress;
// mock addresses

fn admin() -> ContractAddress {
    contract_address_const::<
            0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2
        >()
}

fn badguy() -> ContractAddress {
    contract_address_const::<
            0x0296c11Fed1F140c73df4EAE033020403E3cA3720c110Be44Ba953144d8A9643
        >()
}

fn user() -> ContractAddress {
    contract_address_const::<
            0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2
        >()
}

fn treasury() -> ContractAddress {
    contract_address_const::<
            0x063b0100292e3547041b4d13147539b9fa873c31e4d84b686f422c490e2163c3
        >()
}

fn finalizer() -> ContractAddress {
    contract_address_const::<
            0x31c66f44d8455e5cac18b7016476685af8bd78bf4128cb5375ff2c45bc137c2
        >()
}
