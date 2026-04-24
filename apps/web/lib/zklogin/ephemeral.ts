import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { generateNonce, generateRandomness } from "@mysten/zklogin";
import { suiClient } from "@/lib/sui";

export async function newEphemeralKey() {
  const { epoch } = await suiClient.getLatestSuiSystemState();
  const maxEpoch = Number(epoch) + 2;
  const ephemeralKey = Ed25519Keypair.generate();
  const randomness = generateRandomness();
  const nonce = generateNonce(ephemeralKey.getPublicKey(), maxEpoch, randomness);
  return {
    maxEpoch,
    randomness,
    nonce,
    ephemeralSecret: ephemeralKey.getSecretKey(), // bech32
  };
}

export function keyFromSecret(secret: string) {
  return Ed25519Keypair.fromSecretKey(secret);
}
