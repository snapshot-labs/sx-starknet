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
    let mut res = 1_u256;
    loop {
        if exp == 0 {
            break res;
        } else {
            res = base * res;
        }
        exp = exp - 1;
    }
}

fn pow_u128(base: u128, mut exp: u8) -> u128 {
    let mut res = 1_u128;
    loop {
        if exp == 0 {
            break res;
        } else {
            res = base * res;
        }
        exp = exp - 1;
    }
}


fn u64s_into_u256(word1: u64, word2: u64, word3: u64, word4: u64) -> u256 {
    // TODO: use consts when supported
    let word1_shifted = word1.into() * pow_u128(2_u128, 64_u8);
    let word3_shifted = word3.into() * pow_u128(2_u128, 64_u8);
    u256 { low: word1_shifted + word2.into(), high: word3_shifted + word4.into() }
}
