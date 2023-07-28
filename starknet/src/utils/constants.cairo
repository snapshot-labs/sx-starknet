const PROPOSE_SELECTOR: felt252 = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
const VOTE_SELECTOR: felt252 = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;
const UPDATE_PROPOSAL_SELECTOR: felt252 =
    0x1f93122f646d968b0ce8c1a4986533f8b4ed3f099122381a4f77478a480c2c3;

const ETHEREUM_PREFIX: u128 = 0x1901;

// TODO: Decide on contents of Domain
// Name, Version, Chain ID, Verifying Contract
const DOMAIN_TYPEHASH_HIGH: u128 = 0x8b73c3c69bb8fe3d512ecc4cf759cc79;
const DOMAIN_TYPEHASH_LOW: u128 = 0x239f7b179b0ffacaa9a75d522b39400f;

// Not sure exactly how to define the typehashes. Should we use use Solidity types or Cairo ones? 
// keccak256(
//             "Propose(ContractAddress space,ContractAddress author,Strategy execution_strategy,"
//             "uint8[] user_proposal_validation_params,uint256 salt)"
//             "Strategy(ContractAddress address,uint8[] params)"
//         )
const PROPOSE_TYPEHASH_HIGH: u128 = 0xb3819ccd8da0765bcd8ddb0565804a77;
const PROPOSE_TYPEHASH_LOW: u128 = 0xf68d3517c389b0125db8929ffa949667;

// keccak256(
//             "Vote(ContractAddress space,ContractAddress voter,Choice choice,"
//             "IndexedStrategy[] user_voting_strategies)"
//             "IndexedStrategy(uint256 index,uint8[] params)"
//         )
const VOTE_TYPEHASH_HIGH: u128 = 0x96d1d90c026a09b7b038acf99c5e292a;
const VOTE_TYPEHASH_LOW: u128 = 0x7b8d480ba77d954029dd696edd6333cc;

// keccak256(
//             "UpdateProposal(ContractAddress space,ContractAddress author,uint256 proposal_id,"
//             "Strategy execution_strategy)"
//             "Strategy(ContractAddress address,uint8[] params)"
//         )
const UPDATE_PROPOSAL_TYPEHASH_HIGH: u128 = 0xe696044e69e092275313905ca33fa3d0;
const UPDATE_PROPOSAL_TYPEHASH_LOW: u128 = 0x2580ebe8785ab31624d10836156f45b3;

// keccak256("Strategy(ContractAddress address,uint8[] params)")
const STRATEGY_TYPEHASH_HIGH: u128 = 0x0ccb9059759f3ea104c9200ef8a59445;
const STRATEGY_TYPEHASH_LOW: u128 = 0x78d5506febfdb18580ea361801747e63;

// keccak256("IndexedStrategy(uint256 index,uint8[] params)")
const INDEXED_STRATEGY_TYPEHASH_HIGH: u128 = 0x894665428ec742c74109dc21d320d1ab;
const INDEXED_STRATEGY_TYPEHASH_LOW: u128 = 0x8b36195eec0090e913c01e7534729c74;


// ------ Stark Sig Constants ------

const STARKNET_MESSAGE: felt252 = 0x537461726b4e6574204d657373616765;
const DOMAIN_HASH: felt252 = 0x133d0430d262d06e2d4aff2851ca256738e40d43593c998ff664b5d5cb410d3;
const PROPOSE_TYPEHASH: felt252 = 0x2e1c0f94a230342f46b462fd4d3bd306f935317123fb9985b08496e8f4f4183;
const STRATEGY_TYPEHASH: felt252 = 0x14c6b221e639b0d611fd0aab18c0c1e29079e17e0445bebd85b5cad1aaaee2b;