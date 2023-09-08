use sx::utils::math;

/// A strategy identified by a unique index. 
#[derive(Option, Clone, Drop, Serde)]
struct IndexedStrategy {
    /// The index of the strategy.
    index: u8,
    /// The corresponding parameters to use.
    params: Array<felt252>,
}

trait IndexedStrategyTrait {
    fn assert_no_duplicate_indices(self: Span<IndexedStrategy>);
}

impl IndexedStrategyImpl of IndexedStrategyTrait {
    fn assert_no_duplicate_indices(self: Span<IndexedStrategy>) {
        let mut self = self;
        if self.len() < 2 {
            return ();
        }

        let mut bit_map = 0_u256;
        loop {
            match self.pop_front() {
                Option::Some(indexed_strategy) => {
                    // Check that bit at index `strats[i].index` is not set.
                    let s = math::pow(2_u256, *indexed_strategy.index);

                    assert((bit_map & s) != 1_u256, 'Duplicate Found');
                    // Update aforementioned bit.
                    bit_map = bit_map | s;
                },
                Option::None => {
                    break;
                },
            };
        };
    }
}
