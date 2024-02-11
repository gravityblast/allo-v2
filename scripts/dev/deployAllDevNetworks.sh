#!/bin/bash


# Using the second account (index 1) of the test mnemonic ,
# we will have the following determinictic addresses on a clean
# local chain:
# Registry: 0x948B3c65b89DF0B4894ABE91E6D02FE579834F8F
# ContractFactory: 0x712516e61C8B383dF4A63CFe83d7701Bce54B03e
# Allo: 0x59F2f1fCfE2474fD5F0b9BA1E73ca90b143Eb8d0
# DonationVotingMerkleDistributionDirectTransferStrategy: 0x3574b2e3eE1F948d61cB0b6B20cC19a63F56E2c4

export SKIP_VERIFICATION=true

timestamp=$(date +"%Y%m%d_%H%M%S")

error_count=0

# Function to log messages
log() {
    local msg=$1
    echo "$(date +'%Y%m%d_%H%M%S') - $msg"
}

# Function to handle errors
error_handler() {
    local error_code=$1
    local cmd=$2
    log "Error code $error_code while executing: $cmd"
    ((error_count++))
}

handle_insufficient_funds_error() {
    local cmd=$1
    log "Insufficient funds error while executing: $cmd"
}

networks=(
    "dev1"
    "dev2"
)

scripts=(
    "core/deployRegistry"
    "core/deployContractFactory"
    "core/deployAllo"
    # "core/transferProxyAdminOwnership"
    "strategies/deployDonationVotingMerkleDistributionDirect"
    # "strategies/deployDonationVotingMerkleDistributionVault"
    # "strategies/deployQVSimple"
    # "strategies/deployRFPCommittee"
    # "strategies/deployRFPSimple"

    # "strategies/deployImpactStream"
)

for script in "${scripts[@]}"; do
    # Execute the commands
    for n in "${networks[@]}"; do
        cmd="npx hardhat run scripts/$script.ts --no-compile --network $n"
        log "Executing: $cmd"
        # Extract the individual log file path from the command string
        # Remove the tee command from the command string
        cmd=${cmd%|*}
        # Define a temporary file to hold the command output
        temp_file=$(mktemp)
        {
            # Evaluate the command, redirect stderr to stdout, and tee to the temporary file
            eval $cmd 2>&1 | tee $temp_file
        }
        # Check for the specific error message in the temporary file
        grep -q "insufficient funds for gas * price + value" $temp_file && handle_insufficient_funds_error "$cmd"
    done

    log "Deployment finished with $error_count error(s)"
done
