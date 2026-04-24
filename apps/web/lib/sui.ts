import { SuiClient } from "@mysten/sui/client";
import { SuiGraphQLClient } from "@mysten/sui/graphql";

export const FULLNODE_URL = process.env.NEXT_PUBLIC_FULLNODE_URL!;
export const GRAPHQL_URL = process.env.NEXT_PUBLIC_GRAPHQL_URL!;

export const suiClient = new SuiClient({ url: FULLNODE_URL });
export const gqlClient = new SuiGraphQLClient({ url: GRAPHQL_URL });
