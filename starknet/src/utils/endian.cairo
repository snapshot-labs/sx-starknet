const MASK_LOW: u128 = 0xffffffffffffffff; // 2^64 - 1
const MASK_HIGH: u128 = 0xffffffffffffffff0000000000000000; // 2^128 - 2^64
const SHIFT_64: u128 = 0x10000000000000000;

// Converts a u256 into a tuple of 4 u64s in little endian order
fn uint256_into_le_u64s(self: u256) -> (u64, u64, u64, u64) {
    let low_low = integer::u128_byte_reverse(self.low & MASK_LOW) / SHIFT_64;
    let low_high = integer::u128_byte_reverse(self.low & MASK_HIGH);
    let high_low = integer::u128_byte_reverse(self.high & MASK_LOW) / SHIFT_64;
    let high_high = integer::u128_byte_reverse(self.high & MASK_HIGH);
    (
        low_high.try_into().unwrap(),
        low_low.try_into().unwrap(),
        high_high.try_into().unwrap(),
        high_low.try_into().unwrap()
    )
}

// Converts an array of u256s into an array of u64s in little endian order 
// NOT FOR GENERAL USE. Reverts if the final u256 fits does not fit into a single u64.
fn into_le_u64_array(self: Array<u256>) -> (Array<u64>, u64) {
    let mut self = self;
    let mut out = ArrayTrait::<u64>::new();

    let overflow = loop {
        match self.pop_front() {
            Option::Some(num) => {
                let (low_high, low_low, high_high, high_low) = uint256_into_le_u64s(num);
                if self.len() == 0 {
                    assert(low_high == 0, 'Final u256 overflows u64');
                    assert(low_low == 0, 'Final u256 overflows u64');
                    assert(high_low == 0, 'Final u256 overflows u64');
                    break (high_high);
                }
                out.append(high_high);
                out.append(high_low);
                out.append(low_high);
                out.append(low_low);
            },
            Option::None => {
                panic_with_felt252('Array should not be empty!');
            }
        };
    };
    (out, overflow)
}

trait ByteReverse<T> {
    fn byte_reverse(self: T) -> T;
}

impl ByteReverseU256 of ByteReverse<u256> {
    fn byte_reverse(self: u256) -> u256 {
        u256 {
            low: integer::u128_byte_reverse(self.high), high: integer::u128_byte_reverse(self.low)
        }
    }
}
