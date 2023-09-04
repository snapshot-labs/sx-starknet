use integer::{Bitwise, U256BitOr, U256BitNot, U128IntoFelt252, Felt252IntoU256, BoundedInt};
use sx::utils::math::pow;

trait BitSetter<T> {
    fn set_bit(ref self: T, index: u8, bit: bool);
    fn is_bit_set(self: T, index: u8) -> bool;
}

impl U256BitSetter of BitSetter<u256> {
    /// Sets the bit at the given index to 1.
    #[inline(always)]
    fn set_bit(ref self: u256, index: u8, bit: bool) {
        let mask = pow(2_u256, index);
        if bit {
            self = self | mask;
        } else {
            self = self & (~mask);
        }
    }

    /// Returns true if the bit at the given index is set to 1.
    #[inline(always)]
    fn is_bit_set(self: u256, index: u8) -> bool {
        let mask = pow(2_u256, index);
        (self & mask).is_non_zero()
    }
}

