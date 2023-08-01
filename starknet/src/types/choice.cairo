use serde::Serde;
use traits::Into;
use hash::LegacyHash;


#[derive(Copy, Drop, Serde)]
enum Choice {
    Against: (),
    For: (),
    Abstain: ()
}

impl ChoiceIntoU8 of Into<Choice, u8> {
    fn into(self: Choice) -> u8 {
        match self {
            Choice::Against(_) => 0_u8,
            Choice::For(_) => 1_u8,
            Choice::Abstain(_) => 2_u8,
        }
    }
}

impl ChoiceIntoU256 of Into<Choice, u256> {
    fn into(self: Choice) -> u256 {
        ChoiceIntoU8::into(self).into()
    }
}

impl LegacyHashChoice of LegacyHash<Choice> {
    fn hash(state: felt252, value: Choice) -> felt252 {
        LegacyHash::hash(state, ChoiceIntoU8::into(value))
    }
}
