import { jwtToAddress } from "@mysten/zklogin";
export function deriveAddress(jwt: string, salt: string) {
  return jwtToAddress(jwt, salt);
}
