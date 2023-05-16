use quaireaux_math::pow;
use traits::Into;
use integer::{U256BitOr, U8IntoU128, U128IntoFelt252, Felt252IntoU256};

fn set_bit(number: u256, index: u8) -> u256 {
    let mask: u128 = pow(2, index.into());
    let mask: felt252 = mask.into();
    number | mask.into()
}

