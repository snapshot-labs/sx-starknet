struct Proposal:
    member execution_hash : felt  # TODO: Use Hash type
    member start_timestamp : felt
    member end_timestamp : felt
    member ethereum_block_number : felt
end
