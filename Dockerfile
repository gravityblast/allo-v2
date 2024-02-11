# FROM oven/bun:1.0.26 as base
FROM node:20-slim as base

RUN apt-get update && \
    apt-get install -y git curl build-essential && \
    apt-get clean

COPY . /app
WORKDIR /app

RUN curl -L https://foundry.paradigm.xyz | bash
RUN ~/.foundry/bin/foundryup

# RUN bun install
RUN corepack enable
RUN pnpm install

FROM base as prod
RUN apt-get update && \
    apt-get install -y curl git && \
    apt-get clean  -y && \
    rm -rf /var/lib/apt/lists/*

COPY . /app
WORKDIR /app

COPY --from=base /app/node_modules /app/node_modules
COPY --from=base /root/.foundry /root/.foundry

ENV PATH="/root/.foundry/bin:$PATH"

# building with bun works but it fails running hardhat scripts
# so we temporarily use pnpm
# RUN bun run build

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

RUN pnpm run build

EXPOSE 8545/tcp
