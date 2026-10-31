import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const [mode, input, output] = process.argv.slice(2);
const key = Buffer.from(process.env.BUNDLE_KEY ?? "", "base64");
if (key.length !== 32) throw new Error("A 256-bit bundle key is required");
const data = readFileSync(input);
if (mode === "encrypt") {
  const nonce = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, nonce);
  const encrypted = Buffer.concat([cipher.update(data), cipher.final()]);
  writeFileSync(output, Buffer.concat([nonce, encrypted, cipher.getAuthTag()]));
} else if (mode === "decrypt") {
  const cipher = createDecipheriv("aes-256-gcm", key, data.subarray(0, 12));
  cipher.setAuthTag(data.subarray(-16));
  writeFileSync(output, Buffer.concat([cipher.update(data.subarray(12, -16)), cipher.final()]));
} else throw new Error("Choose encrypt or decrypt");
