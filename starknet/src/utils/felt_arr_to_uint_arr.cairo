use array::ArrayTrait;
use traits::Into;

impl Felt252ArrayIntoU256Array of Into<Array<felt252>, Array<u256>> {
    fn into(self: Array<felt252>) -> Array<u256> {
        let mut arr = ArrayTrait::<u256>::new();
        let mut i = 0_usize;
        loop {
            if i >= self.len() {
                break ();
            }
            arr.append((*self.at(i)).into());
            i += 1;
        };
        arr
    }
}
