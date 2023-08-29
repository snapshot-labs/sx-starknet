use serde::Serde;
use traits::{Into, PartialEq};
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

impl ChoiceEq of PartialEq<Choice> {
    fn eq(lhs: @Choice, rhs: @Choice) -> bool {
        ChoiceIntoU8::into(*lhs) == ChoiceIntoU8::into(*rhs)
    }

    fn ne(lhs: @Choice, rhs: @Choice) -> bool {
        ChoiceIntoU8::into(*lhs) != ChoiceIntoU8::into(*rhs)
    }
}
