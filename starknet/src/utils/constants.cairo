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


// ------ Stark Signature Constants ------

const STARKNET_MESSAGE: felt252 = 'StarkNet Message';

// H('StarkNetDomain(name:felt252,version:felt252,chainId:felt252,verifyingContract:ContractAddress)')
const DOMAIN_TYPEHASH: felt252 = 0xa9974a36dee531bbc36aad5eeab4ade4df5ad388a296bb14d28ad4e9bf2164;

// H('Propose(space:ContractAddress,author:ContractAddress,executionStrategy:Strategy,
//    userProposalValidationParams:felt*,metadataURI:felt*,salt:felt252)Strategy(address:felt252,params:felt*)')
const PROPOSE_TYPEHASH: felt252 = 0x248246f9067bb8dd7f7661e894ff088ed3e08cb0957df6cf9c9044cc71fffcb;

// H('Vote(space:ContractAddress,voter:ContractAddress,proposalId:u256,choice:felt252,
//    userVotingStrategies:IndexedStrategy*,metadataURI:felt*)IndexedStrategy(index:felt252,params:felt*)
//    u256(low:felt252,high:felt252)')
const VOTE_TYPEHASH: felt252 = 0x3ef46c9599d94309c080fa67cc9f79a94483b2a3ac938a28bba717aca5e1983;

// H('UpdateProposal(space:ContractAddress,author:ContractAddress,proposalId:u256,executionStrategy:Strategy,
//    metadataURI:felt*,salt:felt252)Strategy(address:felt252,params:felt*)u256(low:felt252,high:felt252)')
const UPDATE_PROPOSAL_TYPEHASH: felt252 =
    0x2dc58602de2862bc8c8dfae763fd5d754f9f4d0b5e6268a403783b7d9164c67;

// H('Strategy(address:felt252,params:felt*)')
const STRATEGY_TYPEHASH: felt252 =
    0x39154ec0efadcd0deffdfc2044cf45dd986d260e59c26d69564b50a18f40f6b;

// H('IndexedStrategy(index:felt252,params:felt*)')
const INDEXED_STRATEGY_TYPEHASH: felt252 =
    0x1f464f3e668281a899c5f3fc74a009ccd1df05fd0b9331b0460dc3f8054f64c;

// H('u256(low:felt252,high:felt252)')
const U256_TYPEHASH: felt252 = 0x1094260a770342332e6a73e9256b901d484a438925316205b4b6ff25df4a97a;

// ------ ERC165 Interface Ids ------
const ERC165_ACCOUNT_INTERFACE_ID: felt252 = 0xa66bd575; // snake 
const ERC165_OLD_ACCOUNT_INTERFACE_ID: felt252 = 0x3943f10f; // camel 
