import config from '@snapshot-labs/eslint-config';

export default [
  ...config,
  // Foundry dependencies: they ship their own prettier configs which pull in
  // plugins that are not installed here.
  { ignores: ['ethereum/lib/**'] }
];
