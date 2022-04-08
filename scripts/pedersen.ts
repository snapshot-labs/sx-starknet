import { computeHashOnElements, pedersen } from 'starknet/dist/utils/hash';
import { toBN } from 'starknet/dist/utils/number';
function main() {
  console.log(
    BigInt(
      computeHashOnElements([
        toBN('0x02d380f4f299a1645235abae1cca8a8c0798c791ec25f3405fce8c0e4225387e'),
        toBN('0x1BFD596AE442867EF71CA523061610682AF8B00FC2738329422F4AD8D220B81'),
        1,
      ])
    )
  );
}
main();
