// OZ ownable module, adding here directly until OZ releases a Scarb package
// Migrated lib to v2
#[starknet::contract]
mod Ownable {
    use starknet::{ContractAddress, get_caller_address};
    use zeroable::Zeroable;

    #[storage]
    struct Storage {
        _owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress
    }

    #[internal]
    fn initializer(ref self: ContractState) {
        let caller: ContractAddress = get_caller_address();
        _transfer_ownership(ref self, caller);
    }

    #[internal]
    fn assert_only_owner(self: @ContractState) {
        let owner: ContractAddress = self._owner.read();
        let caller: ContractAddress = get_caller_address();
        assert(!caller.is_zero(), 'Caller is the zero address');
        assert(caller == owner, 'Caller is not the owner');
    }

    #[internal]
    fn owner(self: @ContractState) -> ContractAddress {
        self._owner.read()
    }

    #[internal]
    fn transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        assert(!new_owner.is_zero(), 'New owner is the zero address');
        assert_only_owner(@self);
        _transfer_ownership(ref self, new_owner);
    }

    #[internal]
    fn renounce_ownership(ref self: ContractState) {
        assert_only_owner(@self);
        _transfer_ownership(ref self, Zeroable::zero());
    }

    #[internal]
    fn _transfer_ownership(ref self: ContractState, new_owner: ContractAddress) {
        let previous_owner: ContractAddress = self._owner.read();
        self._owner.write(new_owner);
        self.emit(Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner }));
    }
}
