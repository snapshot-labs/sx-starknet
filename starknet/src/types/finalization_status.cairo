use serde::Serde;
use array::ArrayTrait;

#[derive(Drop, Serde, PartialEq, Copy, starknet::Store)]
enum FinalizationStatus {
    Pending: (),
    Executed: (),
    Cancelled: (),
}

impl U8IntoFinalizationStatus of TryInto<u8, FinalizationStatus> {
    fn try_into(self: u8) -> Option<FinalizationStatus> {
        if self == 0_u8 {
            Option::Some(FinalizationStatus::Pending(()))
        } else if self == 1_u8 {
            Option::Some(FinalizationStatus::Executed(()))
        } else if self == 2_u8 {
            Option::Some(FinalizationStatus::Cancelled(()))
        } else {
            Option::None(())
        }
    }
}

impl FinalizationStatusIntoU8 of Into<FinalizationStatus, u8> {
    fn into(self: FinalizationStatus) -> u8 {
        match self {
            FinalizationStatus::Pending(_) => 0_u8,
            FinalizationStatus::Executed(_) => 1_u8,
            FinalizationStatus::Cancelled(_) => 2_u8,
        }
    }
}
