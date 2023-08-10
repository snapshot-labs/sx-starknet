const PROPOSE_SELECTOR: felt252 = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
const VOTE_SELECTOR: felt252 = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;
const UPDATE_PROPOSAL_SELECTOR: felt252 =
    0x1f93122f646d968b0ce8c1a4986533f8b4ed3f099122381a4f77478a480c2c3;

const ETHEREUM_PREFIX: u128 = 0x1901;

// TODO: Decide on contents of Domain
// Name, Version, Chain ID, Verifying Contract
const DOMAIN_TYPEHASH_HIGH: u128 = 0xc49a8e302e3e5d6753b2bb3dbc3c28de;
const DOMAIN_TYPEHASH_LOW: u128 = 0xba5e16e2572a92aef568063c963e3465;

// Not sure exactly how to define the typehashes. Should we use use Solidity types or Cairo ones? 
// keccak256(
//    "Propose(uint256 authenticator,uint256 space,address author,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const PROPOSE_TYPEHASH_HIGH: u128 = 0x1011cba89700b1acfdd40a56dbfd2960;
const PROPOSE_TYPEHASH_LOW: u128 = 0xe4866ef5e07732f3e3560c820e90fe2f;

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

// keccak256("Strategy(uint256 address,uint256[] params)")
const STRATEGY_TYPEHASH_HIGH: u128 = 0xa6cb034787a88e7219605b9db792cb9a;
const STRATEGY_TYPEHASH_LOW: u128 = 0x312314462975078b4bdad10feee486d9;

// keccak256("IndexedStrategy(uint256 index,uint8[] params)")
const INDEXED_STRATEGY_TYPEHASH_HIGH: u128 = 0x894665428ec742c74109dc21d320d1ab;
const INDEXED_STRATEGY_TYPEHASH_LOW: u128 = 0x8b36195eec0090e913c01e7534729c74;
