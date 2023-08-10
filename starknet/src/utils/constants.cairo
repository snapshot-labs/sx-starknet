const PROPOSE_SELECTOR: felt252 = 0x1bfd596ae442867ef71ca523061610682af8b00fc2738329422f4ad8d220b81;
const VOTE_SELECTOR: felt252 = 0x132bdf85fc8aa10ac3c22f02317f8f53d4b4f52235ed1eabb3a4cbbe08b5c41;
const UPDATE_PROPOSAL_SELECTOR: felt252 =
    0x1f93122f646d968b0ce8c1a4986533f8b4ed3f099122381a4f77478a480c2c3;

const ETHEREUM_PREFIX: u128 = 0x1901;

// keccak256("EIP712Domain(uint256 chainId)")
const DOMAIN_TYPEHASH_HIGH: u128 = 0xc49a8e302e3e5d6753b2bb3dbc3c28de;
const DOMAIN_TYPEHASH_LOW: u128 = 0xba5e16e2572a92aef568063c963e3465;

// keccak256(
//    "Propose(uint256 authenticator,uint256 space,address author,Strategy executionStrategy,uint256[] userProposalValidationParams,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const PROPOSE_TYPEHASH_HIGH: u128 = 0x1011cba89700b1acfdd40a56dbfd2960;
const PROPOSE_TYPEHASH_LOW: u128 = 0xe4866ef5e07732f3e3560c820e90fe2f;

// keccak256(
//    "Vote(uint256 authenticator,uint256 space,address voter,uint256 proposalId,uint256 choice,IndexedStrategy[] userVotingStrategies)IndexedStrategy(uint256 index,uint256[] params)"
//         )
const VOTE_TYPEHASH_HIGH: u128 = 0x8c7b06f800b2d19203061aaf87d18422;
const VOTE_TYPEHASH_LOW: u128 = 0x3adaedc5d7d0019ca84c2985f87a37bc;

// keccak256(
//    "UpdateProposal(uint256 authenticator,uint256 space,address author,uint256 proposalId,Strategy executionStrategy,uint256 salt)Strategy(uint256 address,uint256[] params)"
//         )
const UPDATE_PROPOSAL_TYPEHASH_HIGH: u128 = 0x40d2edfc30a6c2f3db15e88660bc1a92;
const UPDATE_PROPOSAL_TYPEHASH_LOW: u128 = 0x72b77b619e97d1b0120af84bb49b15a2;

// keccak256("Strategy(uint256 address,uint256[] params)")
const STRATEGY_TYPEHASH_HIGH: u128 = 0xa6cb034787a88e7219605b9db792cb9a;
const STRATEGY_TYPEHASH_LOW: u128 = 0x312314462975078b4bdad10feee486d9;

// keccak256("IndexedStrategy(uint256 index,uint256[] params)")
const INDEXED_STRATEGY_TYPEHASH_HIGH: u128 = 0xf4acb5967e70f3ad896d52230fe743c9;
const INDEXED_STRATEGY_TYPEHASH_LOW: u128 = 0x1d011b57ff63174d8f2b064ab6ce9cc6;
