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
