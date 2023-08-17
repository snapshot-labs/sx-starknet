const PROPOSE_SELECTOR: felt252 = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
const VOTE_SELECTOR: felt252 = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;
const UPDATE_PROPOSAL_SELECTOR: felt252 =
    0x1f93122f646d968b0ce8c1a4986533f8b4ed3f099122381a4f77478a480c2c3;

// ------ Ethereum Signature Constants ------

const ETHEREUM_PREFIX: u128 = 0x1901;

// keccak256("EIP712Domain(uint256 chainId)")
const DOMAIN_TYPEHASH_HIGH: u128 = 0xc49a8e302e3e5d6753b2bb3dbc3c28de;
const DOMAIN_TYPEHASH_LOW: u128 = 0xba5e16e2572a92aef568063c963e3465;

// keccak256(
//    "Propose(uint256 authenticator,uint256 space,address author,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256[] metadataURI,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const PROPOSE_TYPEHASH_HIGH: u128 = 0x4c19381009c47ff3cfe749938b25f5e4;
const PROPOSE_TYPEHASH_LOW: u128 = 0xb63c57d1ce7718eabe7751c6b7994a5a;

// keccak256(
//    "Vote(uint256 authenticator,uint256 space,address voter,uint256 proposalId,uint256 choice,IndexedStrategy[] userVotingStrategies,uint256[] metadataURI)IndexedStrategy(uint256 index,uint256[] params)"
//         )
const VOTE_TYPEHASH_HIGH: u128 = 0xf587b4fe40b9aeb214b3e3d862114bfe;
const VOTE_TYPEHASH_LOW: u128 = 0x59cfeb94ba744089037ceeb63def96ef;

// keccak256(
//    "UpdateProposal(uint256 authenticator,uint256 space,address author,uint256 proposalId,Strategy executionStrategy,uint256[] metadataURI,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const UPDATE_PROPOSAL_TYPEHASH_HIGH: u128 = 0x8a221be7eb055e510516ec8289334a52;
const UPDATE_PROPOSAL_TYPEHASH_LOW: u128 = 0x28aac537859e4342e572bb36547b7139;

// keccak256("Strategy(uint256 address,uint256[] params)")
const STRATEGY_TYPEHASH_HIGH: u128 = 0xa6cb034787a88e7219605b9db792cb9a;
const STRATEGY_TYPEHASH_LOW: u128 = 0x312314462975078b4bdad10feee486d9;

// keccak256("IndexedStrategy(uint256 index,uint256[] params)")
const INDEXED_STRATEGY_TYPEHASH_HIGH: u128 = 0xf4acb5967e70f3ad896d52230fe743c9;
const INDEXED_STRATEGY_TYPEHASH_LOW: u128 = 0x1d011b57ff63174d8f2b064ab6ce9cc6;

// ------ Stark Signature Constants ------

const STARKNET_MESSAGE: felt252 = 'StarkNet Message';

// StarknetKeccak('StarkNetDomain(name:felt252,version:felt252,chainId:felt252,verifyingContract:ContractAddress)')
const DOMAIN_TYPEHASH: felt252 = 0xa9974a36dee531bbc36aad5eeab4ade4df5ad388a296bb14d28ad4e9bf2164;

// StarknetKeccak('Propose(space:ContractAddress,author:ContractAddress,executionStrategy:Strategy,
//    userProposalValidationParams:felt*,metadataURI:felt*,salt:felt252)Strategy(address:felt252,params:felt*)')
const PROPOSE_TYPEHASH: felt252 = 0x248246f9067bb8dd7f7661e894ff088ed3e08cb0957df6cf9c9044cc71fffcb;

// StarknetKeccak('Vote(space:ContractAddress,voter:ContractAddress,proposalId:u256,choice:felt252,
//    userVotingStrategies:IndexedStrategy*,metadataURI:felt*)IndexedStrategy(index:felt252,params:felt*)
//    u256(low:felt252,high:felt252)')
const VOTE_TYPEHASH: felt252 = 0x3ef46c9599d94309c080fa67cc9f79a94483b2a3ac938a28bba717aca5e1983;

// StarknetKeccak('UpdateProposal(space:ContractAddress,author:ContractAddress,proposalId:u256,executionStrategy:Strategy,
//    metadataURI:felt*,salt:felt252)Strategy(address:felt252,params:felt*)u256(low:felt252,high:felt252)')
const UPDATE_PROPOSAL_TYPEHASH: felt252 =
    0x2dc58602de2862bc8c8dfae763fd5d754f9f4d0b5e6268a403783b7d9164c67;

// StarknetKeccak('Strategy(address:felt252,params:felt*)')
const STRATEGY_TYPEHASH: felt252 =
    0x39154ec0efadcd0deffdfc2044cf45dd986d260e59c26d69564b50a18f40f6b;

// StarknetKeccak('IndexedStrategy(index:felt252,params:felt*)')
const INDEXED_STRATEGY_TYPEHASH: felt252 =
    0x1f464f3e668281a899c5f3fc74a009ccd1df05fd0b9331b0460dc3f8054f64c;

// StarknetKeccak('u256(low:felt252,high:felt252)')
const U256_TYPEHASH: felt252 = 0x1094260a770342332e6a73e9256b901d484a438925316205b4b6ff25df4a97a;

// ------ ERC165 Interface Ids ------
// For more information, refer to: https://github.com/starknet-io/SNIPs/blob/main/SNIPS/snip-5.md

const ERC165_ACCOUNT_INTERFACE_ID: felt252 = 0xa66bd575; // snake 
const ERC165_OLD_ACCOUNT_INTERFACE_ID: felt252 = 0x3943f10f; // camel 
