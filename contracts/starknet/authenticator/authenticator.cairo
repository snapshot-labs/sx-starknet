%lang starknet

@contract_interface
namespace ISpaceContract:
    func receive(data_len: felt, data: felt*):
    end
end

# Forwards `data` to `target` without verifying anything.
# TODO: use ADDRESS instead of felt
@external
func execute{syscall_ptr: felt*, range_check_ptr}(target: felt, data_len: felt, data: felt*):
    # TODO: Actually verify the signature

    # Call the space contract
    ISpaceContract.receive(contract_address=target, data_len=data_len, data=data)

    return ()
end
