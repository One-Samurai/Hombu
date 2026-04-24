import { getExtendedEphemeralPublicKey, genAddressSeed, getZkLoginSignature } from "@mysten/zklogin";
import { Transaction } from "@mysten/sui/transactions";
import { keyFromSecret } from "./ephemeral";
import { suiClient } from "@/lib/sui";

export async function signAndExecuteZk(params: {
  tx: Transaction;
  ephemeralSecret: string;
  jwt: string;
  userSalt: string;
  maxEpoch: number;
  zkProof: any;
  sender: string;
}) {
  params.tx.setSender(params.sender);
  const key = keyFromSecret(params.ephemeralSecret);
  const { bytes, signature: userSignature } = await params.tx.sign({
    client: suiClient,
    signer: key,
  });
  const decoded = JSON.parse(atob(params.jwt.split(".")[1])) as { sub: string; aud: string };
  const addressSeed = genAddressSeed(
    BigInt(params.userSalt), "sub", decoded.sub,
    Array.isArray(decoded.aud) ? decoded.aud[0] : decoded.aud
  ).toString();
  const zkLoginSignature = getZkLoginSignature({
    inputs: { ...params.zkProof, addressSeed },
    maxEpoch: params.maxEpoch,
    userSignature,
  });
  return suiClient.executeTransactionBlock({
    transactionBlock: bytes,
    signature: zkLoginSignature,
    options: { showEffects: true, showObjectChanges: true, showEvents: true },
  });
}
