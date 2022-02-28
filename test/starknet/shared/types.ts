import {assert, hexToBytes, bytesToHex} from './helpers';

export class IntsSequence {
    values: bigint[];
    bytesLength: number;

    constructor(values: bigint[], bytesLength: number) {
        this.values = values; 
        this.bytesLength = bytesLength;
    }

    toSplitUint256(): SplitUint256 {
        // let fullwords = this.bytesLength % 8;
        let rem = this.bytesLength % 8;
        let uint = this.values[this.values.length-1];
        let shift=BigInt(0);
        if (rem==0) {
            shift+=BigInt(64);
        } else {
            shift+=BigInt(rem*8);
        }
        for (let i=0; i<this.values.length-1; i++) {
            uint+=this.values[this.values.length-2-i]<<BigInt(shift);
            shift+=BigInt(64);
        }
        return SplitUint256.fromUint(uint);
    }

    static fromBytes(bytes: number[]): IntsSequence {
        let ints_array : bigint[] = [];
        for (let i=0; i<bytes.length; i+=8) {
            ints_array.push(BigInt('0x'+bytesToHex(bytes.slice(i+0,i+8))));
        } 
        return new IntsSequence(ints_array, bytes.length);
    }

    static fromUint(uint: bigint): IntsSequence {
        let hex = uint.toString(16);
        if (hex.length%2!=0) {
            hex='0'+hex;
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
        let uint = this.low + (this.high<<BigInt(128));
        return uint;
    }    

    static fromUint(uint: bigint): SplitUint256 {
        assert(uint<(BigInt(1)<<BigInt(256)), "Number too large");
        assert(BigInt(0)<=uint, "Number cannot be negative")
        let low = uint & ((BigInt(1)<<BigInt(128))-BigInt(1));
        let high = uint>>BigInt(128);
        return new SplitUint256(low, high);
    }

    toHex(): string {
        return this.toUint().toString(16);
    }
}