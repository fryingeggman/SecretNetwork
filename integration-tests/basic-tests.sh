#!/bin/bash

SECRETCLI=${1:-./secretcli}
SECRETD_HOME=${2:-$HOME/.secretd_local}
CHAINID=${3:-secretdev-1}
SECRETD=${4:-"http://localhost:26657"}

if [ ! $SECRETD_HOME/config/genesis.json ]; then
  echo "Cannot find $SECRETD_HOME/config/genesis.json."
  exit 1
fi

set -x
set -o errexit

THIS=`readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0`
DIR=`dirname "${THIS}"`
. "$DIR/integration_test_funcs.sh"

# ----- CLIENT CONFIGURATION - START -----
$SECRETCLI config set client chain-id "$CHAINID"
$SECRETCLI config set client output json
$SECRETCLI config set client keyring-backend test
$SECRETCLI config set client node $SECRETD
# ----- CLIENT CONFIGURATION - END -----


# ----- NODE STATUS CHECK - START -----
$SECRETCLI status --output=json | jq
# ----- NODE STATUS CHECK - END -----


# ----- KEY OPERATIONS - START -----
$SECRETCLI keys list --keyring-backend="test" --home=$SECRETD_HOME --output=json | jq

address_v=$($SECRETCLI keys show -a validator --keyring-backend="test" --home=$SECRETD_HOME)

address_a=$($SECRETCLI keys show -a a --keyring-backend="test" --home=$SECRETD_HOME)
address_b=$($SECRETCLI keys show -a b --keyring-backend="test" --home=$SECRETD_HOME)
address_c=$($SECRETCLI keys show -a c --keyring-backend="test" --home=$SECRETD_HOME)
address_d=$($SECRETCLI keys show -a d --keyring-backend="test" --home=$SECRETD_HOME)

key_a=$($SECRETCLI keys show -p a --keyring-backend="test" --home=$SECRETD_HOME)
key_b=$($SECRETCLI keys show -p b --keyring-backend="test" --home=$SECRETD_HOME)
key_c=$($SECRETCLI keys show -p c --keyring-backend="test" --home=$SECRETD_HOME)
key_d=$($SECRETCLI keys show -p d --keyring-backend="test" --home=$SECRETD_HOME)
# ----- KEY OPERATIONS - END -----


# ----- BANK BALANCE TRANSERS - START -----
$SECRETCLI q bank balances $address_a --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_b --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_c --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_d --home=$SECRETD_HOME --output=json | jq

txhash=$($SECRETCLI tx bank send $address_a $address_b 10uscrt --gas-prices=0.25uscrt -y --chain-id=$CHAINID --home=$SECRETD_HOME --keyring-backend="test" --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type="hash" "$txhash" --output=json | jq
$SECRETCLI q bank balances $address_a --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_b --home=$SECRETD_HOME --output=json | jq

txhash=$($SECRETCLI tx bank send $address_b $address_c 10uscrt --gas-prices=0.25uscrt -y --chain-id=$CHAINID --home=$SECRETD_HOME --keyring-backend="test" --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type="hash" "$txhash" --output=json | jq
$SECRETCLI q bank balances $address_b --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_c --home=$SECRETD_HOME --output=json | jq

txhash=$($SECRETCLI tx bank send $address_c $address_d 10uscrt --gas-prices=0.25uscrt -y --chain-id=$CHAINID --home=$SECRETD_HOME --keyring-backend="test" --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type="hash" "$txhash" --output=json | jq
$SECRETCLI q bank balances $address_c --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_d --home=$SECRETD_HOME --output=json | jq

txhash=$($SECRETCLI tx bank send $address_d $address_a 10uscrt --gas-prices=0.25uscrt -y --chain-id=$CHAINID --home=$SECRETD_HOME --keyring-backend="test" --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type="hash" "$txhash" --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_d --home=$SECRETD_HOME --output=json | jq
$SECRETCLI q bank balances $address_a --home=$SECRETD_HOME --output=json | jq
# ----- BANK BALANCE TRANSERS - END -----


# ----- DISTRIBUTIONS - START -----
$SECRETCLI q distribution params --output=json | jq

$SECRETCLI q distribution community-pool --output=json | jq

address_valop=$(jq '.app_state.genutil.gen_txs[0].body.messages[0].validator_address' $SECRETD_HOME/config/genesis.json)

if [[ -z $address_valop ]];then
    echo "No GENESIS tx in genesis.json"
    exit 1
fi

address_valop=$(echo $address_valop | sed 's/"//g')
$SECRETCLI q distribution validator-outstanding-rewards $address_valop --output=json | jq

$SECRETCLI q distribution commission $address_valop --output=json | jq

echo "FIXME: get realistic height"
$SECRETCLI q distribution slashes $address_valop "1" "10" --output=json | jq
# ----- DISTRIBUTIONS - END -----


# -------------------------------------------
DIR=$(pwd)
TMP_DIR=$(mktemp -d -p ${DIR})
if [ ! -d $WORK_DIR ]; then
  echo "Could not create $WORK_DIR"
  exit 1
fi

function cleanup {
    echo "Clean up $TMP_DIR"
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT
# ----------------------------------------------

# ----- SMART CONTRACTS - START -----
$SECRETCLI keys add scrtsc --keyring-backend="test" --home=$SECRETD_HOME --output=json | jq
address_scrt=$($SECRETCLI keys show -a scrtsc --keyring-backend="test" --home=$SECRETD_HOME)
$SECRETCLI q bank balances $address_scrt --home=$SECRETD_HOME --output=json | jq
txhash=$($SECRETCLI tx bank send $address_a $address_scrt 1000000uscrt --gas-prices=0.25uscrt -y --chain-id=$CHAINID --home=$SECRETD_HOME --keyring-backend="test" --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type=hash "$txhash" --output json | jq
$SECRETCLI q bank balances $address_scrt --home=$SECRETD_HOME --output=json | jq

txhash=$($SECRETCLI tx compute store ./integration-tests/test-contracts/contract.wasm.gz -y --gas 950000 --fees 12500uscrt --from $address_scrt --chain-id=$CHAINID --keyring-backend="test" --home=$SECRETD_HOME --output=json | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type=hash "$txhash" --output json | jq
$SECRETCLI q compute list-code --home=$SECRETD_HOME --output json | jq

CONTRACT_LABEL="counterContract"

TMPFILE=$(mktemp -p $TMP_DIR)


res_comp_1=$(mktemp -p $TMP_DIR)
$SECRETCLI tx compute instantiate 1 '{"count": 1}' --from $address_scrt --fees 5000uscrt --label $CONTRACT_LABEL -y --keyring-backend=test --home=$SECRETD_HOME --chain-id $CHAINID --output json | jq > $res_comp_1
txhash=$(cat $res_comp_1 | jq ".txhash" | sed 's/"//g')
sleep 5s
res_q_tx=$(mktemp -p $TMP_DIR)
$SECRETCLI q tx --type=hash "$txhash" --output json | jq > $res_q_tx
code_id=$(cat $res_q_tx | jq ".code")
if [[ ${code_id} -ne 0 ]]; then 
  cat $res_q_tx | jq ".raw_log"
  exit 1
fi
sleep 5s
code_id=$($SECRETCLI q compute list-code --home=$SECRETD_HOME --output json | jq ".code_infos[0].code_id" | sed 's/"//g')
$SECRETCLI q compute list-contract-by-code $code_id --home=$SECRETD_HOME --output json | jq
contr_addr=$($SECRETCLI q compute list-contract-by-code $code_id --home=$SECRETD_HOME --output json | jq ".contract_infos[0].contract_address" | sed 's/"//g')
$SECRETCLI q compute contract $contr_addr --output json | jq
expected_count=$($SECRETCLI q compute query $contr_addr  '{"get_count": {}}' --home=$SECRETD_HOME --output json | jq ".count")
if [[ ${expected_count} -ne 1 ]]; then
  echo "Expected count is 1, got ${expected_count}"
  exit 1
fi
# Scenario 1 - execute by query by contract label
json_compute_s1=$(mktemp -p $TMP_DIR)
$SECRETCLI tx compute execute --label $CONTRACT_LABEL --from scrtsc '{"increment":{}}' -y --home $SECRETD_HOME --keyring-backend test --chain-id $CHAINID --fees 3000uscrt --output json | jq > $json_compute_s1
code_id=$(cat $json_compute_s1 | jq ".code")
if [[ ${code_id} -ne 0 ]]; then 
  cat $json_compute_s1 | jq ".raw_log"
  exit 1
fi
txhash=$(cat $json_compute_s1 | jq ".txhash" | sed 's/"//g')
sleep 5s
$SECRETCLI q tx --type=hash "$txhash" --output json | jq
sleep 5s
expected_count=$($SECRETCLI q compute query $contr_addr  '{"get_count": {}}' --home=$SECRETD_HOME --output json | jq '.count')
if [[ ${expected_count} -ne 2 ]]; then
  echo "Expected count is 2, got ${expected_count}"
  exit 1
fi
# Scenario 2 - execute by contract address
json_compute_s2=$(mktemp -p $TMP_DIR)
$SECRETCLI tx compute execute $contr_addr --from scrtsc '{"increment":{}}' -y --home $SECRETD_HOME --keyring-backend test --chain-id $CHAINID --fees 3000uscrt --output json | jq > $json_compute_s2
code_id=$(cat $json_compute_s2 | jq ".code")
if [[ ${code_id} -ne 0 ]]; then 
  cat $json_compute_s2 | jq ".raw_log"
  exit 1
fi
txhash=$(cat $json_compute_s1 | jq ".txhash" | sed 's/"//g')
$SECRETCLI q tx --type=hash "$txhash" --output json | jq
sleep 5s
expected_count=$($SECRETCLI q compute query $contr_addr  '{"get_count": {}}' --home=$SECRETD_HOME --output json | jq '.count')
if [[ ${expected_count} -ne 3 ]]; then
  echo "Expected count is 3, got ${expected_count}"
  exit 1
fi
# ----- SMART CONTRACTS - END -----

# ------ STAKING - START ----------
val_addr=$($SECRETCLI keys show validator --bech val -a --keyring-backend test --home $SECRETD_HOME)
$SECRETCLI query staking delegations-to $val_addr --output json | jq
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error => $SECRETCLI query staking delegations-to $val_addr"
    exit 1
fi

# Account A stakes 500uscrt to validator
if ! staking_delegate $val_addr $address_a 500; then 
  echo "Staking validation from $address_a to $val_addr with 500uscrt failed"
  exit 1
fi
# Check account A stake with validator - should be 500
if ! staking_check $val_addr $address_a 500; then
  echo "Staking delegations from $address_a to $val_addr is not 500"
  exit 1
fi

# Account B stakes 1000uscrt to validator
if ! staking_delegate $val_addr $address_b 1000; then 
  echo "Staking validation from $address_b to $val_addr with 1000uscrt failed"
  exit 1
fi
# Check account B stake with validator - should be 1000
if ! staking_check $val_addr $address_b 1000; then
  echo "Staking delegations from $address_b to $val_addr is not 1000"
  exit 1
fi

# Account C stakes 1500uscrt to validator
if ! staking_delegate $val_addr $address_c 1500; then 
  echo "Staking validation from $address_c to $val_addr with 1500uscrt failed"
  exit 1
fi
# Check account C stake with validator - should be 1500
if ! staking_check $val_addr $address_c 1500; then
  echo "Staking delegations from $address_c to $val_addr is not 1500"
  exit 1
fi

# Account D stakes 5000uscrt to validator
if ! staking_delegate $val_addr $address_d 5000; then 
  echo "Staking validation from $address_d to $val_addr with 5000uscrt failed"
  exit 1
fi
# Check account D stake with validator - should be 5000
if ! staking_check $val_addr $address_d 5000; then
  echo "Staking delegations from $address_d to $val_addr is not 5000"
  exit 1
fi

# -------- STAKING - END ----------

# -------- BANKING - START --------
val_addr=$($SECRETCLI keys show -a validator --keyring-backend test --home $SECRETD_HOME)
recep_addr=$($SECRETCLI keys show -a a --keyring-backend test --home $SECRETD_HOME)
$SECRETCLI tx bank send $val_addr $recep_addr 500stake --chain-id $CHAINID --keyring-backend test --home $SECRETD_HOME --fees 3000uscrt --generate-only --output json | jq
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error => $SECRETCLI tx bank send $val_addr $recep_addr 500stake --chain-id $CHAINID --keyring-backend test --home $SECRETD_HOME --fees 3000uscrt --generate-only"
    exit 1
fi
json_bank_send=$(mktemp -p $TMP_DIR)
$SECRETCLI tx bank send $val_addr $recep_addr 500stake --chain-id $CHAINID --keyring-backend test --home $SECRETD_HOME --fees 3000uscrt -y --output json | jq > $json_bank_send
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error => $SECRETCLI tx bank send $val_addr $recep_addr 500stake --chain-id $CHAINID --keyring-backend test --home $SECRETD_HOME --fees 3000uscrt -y"
    exit 1
fi
code_id=$(cat $json_bank_send | jq ".code")
if [[ ${code_id} -ne 0 ]]; then 
  cat $json_bank_send | jq ".raw_log"
  exit 1
fi
txhash=$(cat $json_bank_send | jq ".txhash" | sed 's/"//g')
sleep 5s
json_bank_send_tx=$(mktemp -p $TMP_DIR)
$SECRETCLI q tx --type hash $txhash --output json | jq > $json_bank_send_tx
retVal=$?
if [ $retVal -ne 0 ]; then
    echo "Error => $SECRETCLI q tx --type hash $txhash"
    exit 1
fi
code_id=$(cat $json_bank_send_tx | jq ".code")
if [[ ${code_id} -ne 0 ]]; then 
  cat $json_bank_send_tx | jq ".raw_log"
  exit 1
fi

# -------- BANKING - END ----------