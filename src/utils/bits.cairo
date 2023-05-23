use traits::{Into};
use zeroable::Zeroable;
use integer::{Bitwise, U256BitOr, U8IntoU128, U128IntoFelt252, Felt252IntoU256, BoundedInt};
use alexandria_math::math::pow;

use sx::utils::math::U256Zeroable;

trait BitSetter<T> {
    fn set_bit(self: T, index: u8, bit: bool) -> ();
    fn is_bit_set(self: T, index: u8) -> bool;
}

impl U256BitSetter of BitSetter<u256> {
    /// Sets the bit at the given index to 1.
    #[inline(always)]
    fn set_bit(self: u256, index: u8, bit: bool) -> () {
        let mask: u128 = pow(2, index.into());
        let mask: felt252 = mask.into();
        let mask: u256 = mask.into();
        if bit {
            self | mask;
        } else {
            // TODO: fix this branch with NOT operator (does it exist yet?)
            panic_with_felt252(0);
        // let a = ~mask;
        // self & mask;
        }
    }

    /// Returns true if the bit at the given index is set to 1.
    #[inline(always)]
    fn is_bit_set(self: u256, index: u8) -> bool {
        let mask: u128 = pow(2, index.into());
        let mask: felt252 = mask.into();
        let mask: u256 = mask.into();
        let a = self & mask;
        a.is_non_zero()
    }
}

