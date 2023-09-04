impl Felt252ArrayIntoU256Array of Into<Array<felt252>, Array<u256>> {
    fn into(mut self: Array<felt252>) -> Array<u256> {
        let mut arr = array![];
        loop {
            match self.pop_front() {
                Option::Some(el) => {
                    arr.append(el.into());
                },
                Option::None => {
                    break;
                }
            };
        };
        arr
    }
}
