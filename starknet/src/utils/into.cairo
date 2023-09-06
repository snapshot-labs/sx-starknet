impl Felt252SpanIntoU256Array of Into<Span<felt252>, Array<u256>> {
    fn into(self: Span<felt252>) -> Array<u256> {
        let mut self = self;
        let mut arr = ArrayTrait::<u256>::new();
        loop {
            match self.pop_front() {
                Option::Some(num) => {
                    arr.append(integer::u256_from_felt252(*num));
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
        arr
    }
}

impl TIntoU256<T, impl TIntoFelt252: Into<T, felt252>> of Into<T, u256> {
    fn into(self: T) -> u256 {
        integer::u256_from_felt252(self.into())
    }
}

