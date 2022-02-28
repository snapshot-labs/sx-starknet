struct StorageSlot:
    member word_1 : felt
    member word_2 : felt
    member word_3 : felt
    member word_4 : felt
end

struct IntsSequence:
    member element : felt*
    member element_size_words: felt
    member element_size_bytes: felt
end

struct EthereumAddress:
    member value : felt 
end