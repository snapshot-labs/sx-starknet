import { assert, hexToBytes, bytesToHex } from './helpers';

export const AGAINST = BigInt(1);
export const FOR = BigInt(2);
export const ABSTAIN = BigInt(3);

//TODO: add toBytes for IntsSequence
export class IntsSequence {
  values: bigint[];
  bytesLength: number;

  constructor(values: bigint[], bytesLength: number) {
    this.values = values;
    this.bytesLength = bytesLength;
  }

  toSplitUint256(): SplitUint256 {
    const rem = this.bytesLength % 8;
    let uint = this.values[this.values.length - 1];
    let shift = BigInt(0);
    if (rem == 0) {
      shift += BigInt(64);
    } else {
      shift += BigInt(rem * 8);
    }
    for (let i = 0; i < this.values.length - 1; i++) {
      uint += this.values[this.values.length - 2 - i] << BigInt(shift);
      shift += BigInt(64);
    }
    return SplitUint256.fromUint(uint);
  }

  static fromBytes(bytes: number[]): IntsSequence {
    const ints_array: bigint[] = [];
    for (let i = 0; i < bytes.length; i += 8) {
      ints_array.push(BigInt(bytesToHex(bytes.slice(i + 0, i + 8))));
    }
    return new IntsSequence(ints_array, bytes.length);
  }

  static fromUint(uint: bigint): IntsSequence {
    let hex = uint.toString(16);
    if (hex.length % 2 != 0) {
      hex = '0x0' + hex;
    } else {
      hex = '0x' + hex;
    }
    return IntsSequence.fromBytes(hexToBytes(hex));
  }
}

export class SplitUint256 {
  low: bigint;
  high: bigint;

  constructor(low: bigint, high: bigint) {
    this.low = low;
    this.high = high;
  }

  toUint(): bigint {
    const uint = this.low + (this.high << BigInt(128));
    return uint;
  }

  static fromUint(uint: bigint): SplitUint256 {
    assert(uint < BigInt(1) << BigInt(256), 'Number too large');
    assert(BigInt(0) <= uint, 'Number cannot be negative');
    const low = uint & ((BigInt(1) << BigInt(128)) - BigInt(1));
    const high = uint >> BigInt(128);
    return new SplitUint256(low, high);
  }

  toHex(): string {
    return '0x' + this.toUint().toString(16);
  }

  static fromObj(s: { low: bigint; high: bigint }): SplitUint256 {
    return new SplitUint256(s.low, s.high);
  }
}
