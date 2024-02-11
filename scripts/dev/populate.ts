import path from "path";
import fs from "fs";
import hre, { ethers, upgrades } from "hardhat";
import { alloConfig } from "../config/allo.config";

import {
  Deployments,
  getImplementationAddress,
  verifyContract,
} from "../utils/scripts";

const pinataHost = process.env.PINATA_HOST;
const pinataPort = process.env.PINATA_PORT;
const pinataBaseUrl =
  pinataHost !== undefined && pinataPort !== undefined
    ? `http://${pinataHost}:${pinataPort}`
    : undefined;

function loadFixture(name: string): Buffer {
  const p = path.resolve(__dirname, "./fixtures", `${name}`);
  const data = fs.readFileSync(p);
  return data;
}

// upload to local pinata
async function uploadJSONToPinata(content: any): Promise<string> {
  const { IpfsHash } = await fetch(`${pinataBaseUrl}/pinning/pinJSONToIPFS`, {
    method: "POST",
    headers: {
      Origin: "http://localhost",
      "Content-Type": "application/json",
      Authorization: `Bearer development-token`,
    },
    body: JSON.stringify({
      pinataContent: content,
    }),
  }).then((r) => r.json());

  return IpfsHash;
}

// upload to local pinata
async function uploadFileToPinata(b: Buffer): Promise<string> {
  const body = new FormData();
  body.append("file", new Blob([b]));

  const { IpfsHash } = await fetch(`${pinataBaseUrl}/pinning/pinFileToIPFS`, {
    method: "POST",
    headers: {
      Origin: "http://localhost",
      Authorization: `Bearer development-token`,
    },
    body,
  }).then((r) => r.json());

  return IpfsHash;
}

export async function main() {
  console.log(`🟡 Populating Allo V2 (pinataBaseUrl ${pinataBaseUrl})`);
  if (hre.network.name !== "dev1" && hre.network.name !== "dev2") {
    console.error("This script can only be use in local dev environments");
    process.exit(1);
  }

  const network = await ethers.provider.getNetwork();
  const chainId = Number(network.chainId);
  const account = (await ethers.getSigners())[0];
  const deployments = new Deployments(chainId, "allo");
  const registryAddress = deployments.getRegistry();

  const registry = await ethers.getContractAt("Registry", registryAddress);

  for (let i = 1; i < 4; i++) {
    let metadataCid = "";

    const metadata = JSON.parse(
      loadFixture(`profiles/${i}/metadata.json`).toString()
    );
    metadata.title = `${metadata.title} (${chainId})`;

    if (pinataBaseUrl === undefined) {
      console.warn(
        "⚠️ Skipping upload to pinata, PINATA_HOST and PINATA_PORT not set"
      );
    } else {
      const logo = loadFixture(`profiles/${i}/logo.png`);
      const logoCid = await uploadFileToPinata(logo);
      const banner = loadFixture(`profiles/${i}/banner.png`);
      const bannerCid = await uploadFileToPinata(banner);
      metadata.logoImg = logoCid;
      metadata.bannerImg = bannerCid;
      metadataCid = await uploadJSONToPinata(metadata);
    }

    const resp = await registry.createProfile(
      new Date().getTime(),
      metadata.title,
      { protocol: 1, pointer: "cid" },
      account.address,
      [account.address]
    );

    const rec = await resp.wait();
    console.log(`🟢 Created profile: `, rec.logs[0].args[0]);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
