#[derive(Drop, Default, Serde, PartialEq, Copy, starknet::Store)]
enum FinalizationStatus {
    #[default]
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

impl FinalizationStatusIntoU128 of Into<FinalizationStatus, u128> {
    fn into(self: FinalizationStatus) -> u128 {
        match self {
            FinalizationStatus::Pending(_) => 0_u128,
            FinalizationStatus::Executed(_) => 1_u128,
            FinalizationStatus::Cancelled(_) => 2_u128,
        }
    }
}

impl FinalizationStatusIntoU256 of Into<FinalizationStatus, u256> {
    fn into(self: FinalizationStatus) -> u256 {
        match self {
            FinalizationStatus::Pending(_) => 0_u256,
            FinalizationStatus::Executed(_) => 1_u256,
            FinalizationStatus::Cancelled(_) => 2_u256,
        }
    }
}
