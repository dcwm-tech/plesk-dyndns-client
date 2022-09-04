#!/bin/bash
# requires: apt install jq curl

# All this information can be get by your selfhosted restful api webgui
# url looks like this: https://subdomain.domain.tld:8443/api/v2/?urls.primaryName=Plesk%20REST%20API#/
# from there enter your credentials (top right "Authorize")
# then jump to "DNS" -> "GET /dns/records" -> "Try it out"
# for auth_code goto "Update DNS record /dns/records/{id}" and copy it simply from there

record_id="1234"
record_name="subdomain.domain.tld."
record_ttl="1"
auth_code="authorization: Basic xxxxxxxxxxxxxxxxxxxx"
plesk_url="https://subdomain.domain.tld:8443/api/v2/dns/records"

# DO NOT CHANGE LINES BELOW
ip4=$(curl -s https://ipv4.icanhazip.com/)

# SCRIPT START
echo "[Plesk DDNS] Check Initiated"

# Seek for the record
record4=$(curl -s -X GET "$plesk_url/$record_id" -H  "accept: application/json" -H  "$auth_code")

# Check for error codes
record4_code=$(echo $record4 | jq -r ".code")
if [[ $record4_code == "0" ]]; then
  echo $record4 | jq -r ".message"
  exit 1
fi

# Check for mismatch in record_id and record_name
record4_valid=$(echo $record4 | jq -r ".host")
if [[ $record4_valid != $record_name ]]; then
  echo "[Plesk DDNS] Error mismatch in record_name and record_id"
  exit 1
fi

# Set existing IP address from the fetched record
old_ip4=$(echo "$record4" | jq -r ".value")

# Compare either one is the same
# NOTE: The script will update even one IP remains the same.
if [[ $ip4 == $old_ip4  ]]; then
  echo "[Plesk DDNS] IPs have not changed."
  exit 0
fi

# The execution of update
update4=$(curl -s -X PUT "$plesk_url/$record_id" -H  "accept: application/json" -H  "$auth_code" -H  "Content-Type: application/json" -d "{  \"id\": $record_id,  \"type\": \"A\",  \"host\": \"$record_name\",  \"value\": \"$ip4\",  \"opt\": \"\",  \"ttl\": $record_ttl}")
update4_result=$(echo $update4 | jq -r ".status")

# The moment of truth
if [[ $update4_result != "success" ]]; then
  echo "[Plesk DDNS] Update failed. DUMPING RESULTS:\n$update4"
  exit 1
else
  echo "[Plesk DDNS] Old IPv4: '$old_ip4' to New IPv4: '$ip4' has been synced to Plesk DNS."
  exit 0
fi
