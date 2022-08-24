import Client from "../src/MinaSigner";
import type { Party, Signed } from "../src/TSTypes";

/**
 * This is an example of a Parties transaction. This can be generated by
 * creating a transaction in SnarkyJS and printing it out as JSON.
 *
 * TODO: When there is an example of how to do this in the SnarkyJS repo,
 * use that example instead.
 */
let mockedParties = {
  otherParties: [
    {
      body: {
        publicKey: "B62qieh9a3U8Z4s8c3DHhCyDECqyZLyRtGA5GBDMqqi6Lf1gaHX4hLt",
        tokenId: "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
        update: {
          appState: ["10", null, null, null, null, null, null, null],
          delegate: null,
          verificationKey: {
            data: "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",
            hash: "15836741414052211301983886193856353162526040956490609761139212467629447291325",
          },
          permissions: {
            editState: "Proof",
            send: "Signature",
            receive: "Proof",
            setDelegate: "Signature",
            setPermissions: "Signature",
            setVerificationKey: "Signature",
            setZkappUri: "Signature",
            editSequenceState: "Proof",
            setTokenSymbol: "Signature",
            incrementNonce: "Signature",
            setVotingFor: "Signature",
          },
          zkappUri: null,
          tokenSymbol: null,
          timing: null,
          votingFor: null,
        },
        balanceChange: { magnitude: "0", sgn: "Positive" },
        incrementNonce: false,
        events: [],
        sequenceEvents: [],
        callData: "0",
        callDepth: 0,
        preconditions: {
          network: {
            snarkedLedgerHash: null,
            timestamp: null,
            blockchainLength: { lower: "0", upper: "4294967295" },
            minWindowDensity: { lower: "0", upper: "4294967295" },
            totalCurrency: { lower: "0", upper: "18446744073709551615" },
            globalSlotSinceHardFork: { lower: "0", upper: "4294967295" },
            globalSlotSinceGenesis: { lower: "0", upper: "4294967295" },
            stakingEpochData: {
              ledger: {
                hash: null,
                totalCurrency: { lower: "0", upper: "18446744073709551615" },
              },
              seed: null,
              startCheckpoint: null,
              lockCheckpoint: null,
              epochLength: { lower: "0", upper: "4294967295" },
            },
            nextEpochData: {
              ledger: {
                hash: null,
                totalCurrency: { lower: "0", upper: "18446744073709551615" },
              },
              seed: null,
              startCheckpoint: null,
              lockCheckpoint: null,
              epochLength: { lower: "0", upper: "4294967295" },
            },
          },
          account: {
            balance: { lower: "0", upper: "18446744073709551615" },
            nonce: { lower: "0", upper: "4294967295" },
            receiptChainHash: null,
            publicKey: null,
            delegate: null,
            state: [null, null, null, null, null, null, null, null],
            sequenceState: null,
            provedState: null,
            isNew: null,
          },
        },

        useFullCommitment: true,
        caller: "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf",
      },
      authorization: {
        proof: null,
        signature:
          "2Xvuve2hGHS8UTZSKJrqqkySBvsM4gLz3cJns3BoYo3vtEbfKnfZqG3SHU9gLSBpjV3H7Sho3sha7wDUvqvk88wVp6mdLMt",
      },
    },
  ],
  memo: "E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH",
};
describe("Party", () => {
  let client: Client;

  beforeAll(async () => {
    client = new Client({ network: "mainnet" });
  });

  it("generates a signed party", () => {
    const keypair = client.genKeys();
    const parties = client.signParty(
      {
        parties: mockedParties,
        feePayer: {
          feePayer: keypair.publicKey,
          fee: "1",
          nonce: "0",
          memo: "test memo",
        },
      },
      keypair.privateKey
    );
    expect(parties.data).toBeDefined();
    expect(parties.signature).toBeDefined();
  });

  it("generates a signed party by using signTransaction", () => {
    const keypair = client.genKeys();
    const parties = client.signTransaction(
      {
        parties: mockedParties,
        feePayer: {
          feePayer: keypair.publicKey,
          fee: "1",
          nonce: "0",
          memo: "test memo",
        },
      },
      keypair.privateKey
    ) as Signed<Party>;
    expect(parties.data).toBeDefined();
    expect(parties.signature).toBeDefined();
  });

  it("should throw an error if no fee is passed to the feePayer", () => {
    const keypair = client.genKeys();
    expect(() => {
      client.signParty(
        {
          parties: mockedParties,
          // @ts-ignore - fee is not defined
          feePayer: {
            feePayer: keypair.publicKey,
            nonce: "0",
            memo: "test memo",
          },
        },
        keypair.privateKey
      );
    }).toThrowError("Fee must be greater than 0.001");
  });

  it("should calculate a correct minimum fee", () => {
    expect(client.getPartyMinimumFee(mockedParties.otherParties, 1)).toBe(1);
  });
});
