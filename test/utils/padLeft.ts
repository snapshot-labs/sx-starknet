export function padLeft(input: string) {
  let res: string;
  if (input.startsWith('0x')) {
    res = input.slice(2);
  } else {
    res = input;
  }

  if (res.length != 64) {
    const padding = '0'.repeat(64 - res.length);
    res = padding + res;
  }

  return '0x' + res;
}
