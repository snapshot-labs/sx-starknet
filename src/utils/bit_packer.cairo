use quaireaux_math::pow;
use traits::{Into};
use zeroable::Zeroable;
use integer::{Bitwise, U256BitOr, U8IntoU128, U128IntoFelt252, Felt252IntoU256, BoundedInt};

impl U256Zeroable of Zeroable<u256> {
    #[inline(always)]
    fn zero() -> u256 {
        u256 { low: 0_u128, high: 0_u128 }
    }

    #[inline(always)]
    fn is_zero(self: u256) -> bool {
        self == U256Zeroable::zero()
    }

    #[inline(always)]
    fn is_non_zero(self: u256) -> bool {
        !self.is_zero()
    }
}

/// Sets the bit at the given index to 1.
fn set_bit(number: u256, index: u8, bit: bool) -> u256 {
    let mask: u128 = pow(2, index.into());
    let mask: felt252 = mask.into();
    let mask: u256 = mask.into();
    if bit {
        number | mask
    } else {
        // TODO: fix this branch with NOT operator
        panic_with_felt252(0);
        // let a = ~mask;
        number & mask
    }
}

/// Returns true if the bit at the given index is set to 1.
fn is_bit_set(number: u256, index: u8) -> bool {
    let mask: u128 = pow(2, index.into());
    let mask: felt252 = mask.into();
    let mask: u256 = mask.into();
    let a = number & mask;
    a.is_non_zero()
}

