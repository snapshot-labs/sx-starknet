import fetch from 'cross-fetch';
async function main() {
  global.fetch = fetch;
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
