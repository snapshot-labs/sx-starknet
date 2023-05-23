use zeroable::Zeroable;

// TODO: should be able to import this from the standard lib eventually but its not released atm
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

impl U64Zeroable of Zeroable<u64> {
    fn zero() -> u64 {
        0
    }
    #[inline(always)]
    fn is_zero(self: u64) -> bool {
        self == U64Zeroable::zero()
    }
    #[inline(always)]
    fn is_non_zero(self: u64) -> bool {
        self != U64Zeroable::zero()
    }
}

fn pow(base: u256, mut exp: u8) -> u256 {
    let mut res = u256 { low: 1_u128, high: 0_u128 };
    loop {
        if exp == 0 {
            break res;
        } else {
            res = base * res;
        }
        exp = exp - 1;
    }
}
