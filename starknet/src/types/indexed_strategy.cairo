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

                    assert((bit_map & s) == 0_u256, 'Duplicate Found');
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

#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use core::traits::TryInto;
    use super::{IndexedStrategy, IndexedStrategyTrait};

    #[test]
    #[available_gas(100000000)]
    fn no_duplicates() {
        array![
            IndexedStrategy { index: 0_u8, params: array![1, 2, 3, 4], },
            IndexedStrategy { index: 1_u8, params: array![1, 2, 3, 4], },
            IndexedStrategy { index: 2_u8, params: array![1, 2, 3, 4], },
        ]
            .span()
            .assert_no_duplicate_indices();
    }

    #[test]
    #[available_gas(100000000)]
    fn empty_array() {
        array![].span().assert_no_duplicate_indices();
    }

    #[test]
    #[available_gas(100000000)]
    #[should_panic(expected: ('Duplicate Found',))]
    fn catch_duplicates() {
        array![
            IndexedStrategy { index: 1_u8, params: array![1, 2, 3, 4], },
            IndexedStrategy { index: 1_u8, params: array![1, 2, 3, 4], },
            IndexedStrategy { index: 0_u8, params: array![1, 2, 3, 4], },
        ]
            .span()
            .assert_no_duplicate_indices();
    }

    #[test]
    #[available_gas(10000000000)]
    #[should_panic(expected: ('Duplicate Found',))]
    fn duplicate_at_high_bound() {
        let mut strats = array![];
        let mut i = 0_usize;
        loop {
            if i == 255_usize {
                break;
            }
            strats
                .append(
                    IndexedStrategy { index: i.try_into().unwrap(), params: array![1, 2, 3, 4], }
                );
            i += 1;
        };

        // Add a duplicate.
        strats.append(IndexedStrategy { index: 77_u8, params: array![1, 2, 3, 4], });

        strats.span().assert_no_duplicate_indices();
    }
}
