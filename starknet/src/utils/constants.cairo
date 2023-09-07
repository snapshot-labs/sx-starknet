const INITIALIZE_SELECTOR: felt252 =
    0x79dc0da7c54b95f10aa182ad0a46400db63156920adb65eca2654c0945a463;
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
//    "Propose(uint256 authenticator,uint256 space,address author,uint256[] metadataUri,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const PROPOSE_TYPEHASH_HIGH: u128 = 0x4dfc61ed4ed6dbe067c67c4d27609650;
const PROPOSE_TYPEHASH_LOW: u128 = 0xc15e92250dad00bce5b7a15d803f412c;

// keccak256(
//    "Vote(uint256 authenticator,uint256 space,address voter,uint256 proposalId,uint256 choice,IndexedStrategy[] userVotingStrategies,uint256[] metadataUri)IndexedStrategy(uint256 index,uint256[] params)"
//         )
const VOTE_TYPEHASH_HIGH: u128 = 0x3de8a6075852dd4e4b0b01cdd1c58ed6;
const VOTE_TYPEHASH_LOW: u128 = 0x2e3bdd0734e744e68fbab937d9ec3663;

// keccak256(
//    "UpdateProposal(uint256 authenticator,uint256 space,address author,uint256 proposalId,Strategy executionStrategy,uint256[] metadataUri,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const UPDATE_PROPOSAL_TYPEHASH_HIGH: u128 = 0xccae29691c0af6c4ee02ec442cb0ade3;
const UPDATE_PROPOSAL_TYPEHASH_LOW: u128 = 0x3fc36989a73ba9357060d3eeac00b67f;

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

// H('Propose(space:ContractAddress,author:ContractAddress,executionStrategy:Strategy, userProposalValidationParams:felt*,
//    metadataUri:felt*,salt:felt252)Strategy(address:felt252,params:felt*)')
const PROPOSE_TYPEHASH: felt252 = 0x1c363469fe163e6c76a850cf019c9c91740adbff5962889db4147507d7e1eb7;

// H('Vote(space:ContractAddress,voter:ContractAddress,proposalId:u256,choice:felt252,userVotingStrategies:IndexedStrategy*,
//    metadataUri:felt*)IndexedStrategy(index:felt252,params:felt*)u256(low:felt252,high:felt252)')
const VOTE_TYPEHASH: felt252 = 0x1d9763f87aaaeb271287d4b9c84053d3f201ad61efc2c32a0abfb8cd42347bf;

// H('UpdateProposal(space:ContractAddress,author:ContractAddress,proposalId:u256,executionStrategy:Strategy,
//    metadataUri:felt*,salt:felt252)Strategy(address:felt252,params:felt*)u256(low:felt252,high:felt252)')
const UPDATE_PROPOSAL_TYPEHASH: felt252 =
    0x34f1b3fe98891caddfc18d9b8d3bee36be34145a6e9f7a7bb76a45038dda780;

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
