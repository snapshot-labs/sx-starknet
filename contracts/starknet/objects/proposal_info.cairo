struct ProposalInfo:
    member execution_hash : felt  # TODO: Use Hash type
    member start_block : felt
    member end_block : felt
    member power_for : felt
    member power_against : felt
    member power_abstain : felt
end
