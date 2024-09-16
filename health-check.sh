#!/bin/bash

# Determine if changes should be committed
commit=true
origin=$(git remote get-url origin)
if [[ $origin == *statsig-io/statuspage* ]]; then
  commit=false
fi

# Initialize arrays
KEYSARRAY=()
URLSARRAY=()

# Read configuration file
urlsConfig="./urls.cfg"
if [[ ! -f $urlsConfig ]]; then
  echo "Configuration file $urlsConfig not found."
  exit 1
fi

echo "Reading $urlsConfig"
while IFS='=' read -r key url; do
  if [[ -n $key && -n $url ]]; then
    KEYSARRAY+=("$key")
    URLSARRAY+=("$url")
  else
    echo "Skipping invalid line: $key=$url"
  fi
done < "$urlsConfig"

echo "***********************"
echo "Starting health checks with ${#KEYSARRAY[@]} configs:"

mkdir -p logs

# Function to check URL
check_url() {
  local url=$1
  local result="failed"
  for i in {1..4}; do
    response=$(curl --write-out '%{http_code}' --silent --output /dev/null "$url")
    if [[ "$response" =~ ^(200|202|301|302|307)$ ]]; then
      result="success"
      break
    fi
    sleep 5
  done
  echo "$result"
}

# Perform health checks
for index in "${!KEYSARRAY[@]}"; do
  key="${KEYSARRAY[$index]}"
  url="${URLSARRAY[$index]}"
  echo "  $key=$url"

  result=$(check_url "$url")
  dateTime=$(date +'%Y-%m-%d %H:%M')

  if [[ $commit == true ]]; then
    echo "$dateTime, $result" >> "logs/${key}_report.log"
    # Keep only the last 2000 entries
    tail -n 2000 "logs/${key}_report.log" > "logs/${key}_report.log"
  else
    echo "    $dateTime, $result"
  fi
done

# Commit and push changes
if [[ $commit == true ]]; then
  git add -A --force logs/
  git commit -m '[Automated] Update Health Check Logs'
  git remote set-url origin https://x-access-token:${GH_PAT}@github.com/tekkondps/health-check.git
  git push
fi
