use traits::{Into};
use zeroable::Zeroable;
use integer::{Bitwise, U256BitOr, U8IntoU128, U128IntoFelt252, Felt252IntoU256, BoundedInt};

fn pow(base: u128, mut exp: u128) -> u128 {
    let mut res = 1;
    loop {
        if exp == 0 {
            break res;
        } else {
            res = base * res;
        }
        exp = exp - 1;
    }
}

// TODO: should be able to import this from the standard lib but cant atm
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

