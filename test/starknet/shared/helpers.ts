export function assert(condition: any, message: string = 'Assertion Failed') {
    if (!condition) {
        throw message;
    }
}
export function hexToBytes(hex: string): number[] {
    for (var bytes: number[] = [], c = 0; c < hex.length; c += 2)
        bytes.push(parseInt(hex.substring(c, c+2), 16));
    return bytes;
}
export function bytesToHex(bytes: number[]): string {
    for (var hex = [], i = 0; i < bytes.length; i++) {
        var current = bytes[i] < 0 ? bytes[i] + 256 : bytes[i];
        hex.push((current >>> 4).toString(16));
        hex.push((current & 0xF).toString(16));
    }
    return hex.join("");
}