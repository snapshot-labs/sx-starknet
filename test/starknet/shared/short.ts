export const SHORT_STR_SIZE = 31;

// Utility function to convert a single short string to its short string (felt) representation.
function strToShortStr(shortStr: string): bigint {
  let res = '0x';

  if (shortStr.length > SHORT_STR_SIZE) {
    // String too big
    return BigInt(0);
  }

  for (let i = 0; i < shortStr.length; i++) {
    let toAdd = shortStr.charCodeAt(i).toString(16);

    // If value is < 10, prefix with a 0
    if (toAdd.length % 2 != 0) {
      toAdd = '0' + toAdd;
    }

    res += toAdd;
  }

  return BigInt(res);
}

// Utility function to convert a single short string to its string representation.
function shortStrToStr(shortString: bigint): string {
  let res = '';
  const hexForm = shortString.toString(16);
  const chunkSize = 2;
  if (hexForm.length % chunkSize != 0) {
    return 'ERROR IN PARSING';
  }

  for (let i = 0; i < hexForm.length; i += chunkSize) {
    const s = parseInt(hexForm.slice(i, i + chunkSize), 16);
    res += String.fromCharCode(s);
  }
  return res;
}

/**
 * Converts a string to an array of short strings (felts). A short string can hold 31 'symbols' (ascii).
 * Example: strToShortStrArr("Hello and welcome to Snapshot X. This is the future of governance.")
 *          -> [
 *              0x48656c6c6f20616e642077656c636f6d6520746f20536e617073686f742058,
 *              0x2e20546869732069732074686520667574757265206f6620676f7665726e61,
 *              0x6e63652e
 *              ]
 * Letters are encoded in those numbers (eg: 0x48656c6c6f20616e642077656c636f6d6520746f20536e617073686f742058)
 *                                             H e l l o   a n d   w e l c o m e   t o   S n a p s h o t   X
 * @param str
 * @returns
 */
export function strToShortStrArr(str: string): bigint[] {
  const res: bigint[] = [];
  for (let i = 0; i < str.length; i += SHORT_STR_SIZE) {
    const temp = str.slice(i, i + SHORT_STR_SIZE);
    res.push(strToShortStr(temp));
  }
  return res;
}

/**
 * Converts a short string array to a single string (by converting each individual short string and concatenating them
 * in a single string).
 * Example: shortStrArrToStr([0x48656c6c6f20616e642077656c636f6d6520746f20536e617073686f742058,
 *                            0x2e20546869732069732074686520667574757265206f6620676f7665726e61,
 *                            0x6e63652e])
 *                        -> "Hello and welcome to Snapshot X. This is the future of governance."
 * @param shortStringArr The array of short str to convert
 * @returns The string recovered by concatenating and converting all the short strings
 */
export function shortStrArrToStr(shortStringArr: bigint[]): string {
  let res = '';
  for (const shortStr of shortStringArr) {
    res += shortStrToStr(shortStr);
  }
  return res;
}
