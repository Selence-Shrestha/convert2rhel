#!/bin/bash

# Initialize overall pass flag
all_checks_passed=true

# Helper function to print result
check_result() {
  local message=$1
  local condition=$2
  local green="\e[32m"
  local red="\e[31m"
  local reset="\e[0m"

  if eval "$condition"; then
    echo -e "$message: ${green}PASS${reset}"
  else
    echo -e "$message: ${red}FAIL${reset}"
    all_checks_passed=false
  fi
}

# 1. Check Architecture
arch=$(uname -m)
check_result "Architecture in x86_64 Intel" "[ \"$arch\" = \"x86_64\" ]"

# 2. Check Security (not in FIPS Mode)
fips_mode=$(cat /proc/sys/crypto/fips_enabled 2>/dev/null || echo 0)
check_result "Security not in FIPS Mode" "[ $fips_mode -eq 0 ]"

# 3. Check High Availability (no pacemaker or corosync packages)
ha_installed=$(rpm -qa | grep -E 'pacemaker|corosync' | wc -l)
check_result "No High Availability" "[ $ha_installed -eq 0 ]"

# 4. Check Identity Management (no ipa-server package)
ipa_installed=$(rpm -qa | grep -E 'ipa-server|ipa-server-dns' | wc -l)
check_result "No Identity Management" "[ $ipa_installed -eq 0 ]"

# 5. Check Foreman (no foreman package)
hammer_ping_status=$(hammer ping &>/dev/null; echo $?)
check_result "No Foreman" "[ $hammer_ping_status -ne 0 ]"

# 6. Check RAID (no mdadm package)
raid_active=$(cat /proc/mdstat | grep -c '^md')
check_result "No RAID (No active Software RAID devices)" "[ $raid_active -eq 0 ]"

# 7. Check UEFI Mode and Secure Boot
if [ -d /sys/firmware/efi ]; then
  uefi_mode=true
else
  uefi_mode=false
fi
check_result "No UEFI Mode Enabled" "[ $uefi_mode = false ]"

if ! rpm -q mokutil &>/dev/null; then
  yum install -y mokutil &>/dev/null
fi

secure_boot=$(mokutil --sb-state 2>/dev/null | grep -c 'SecureBoot enabled')
check_result "Secure Boot Disabled" "[ $secure_boot -eq 0 ]"

# 8. Check if system updates are performed
if yum check-update &>/dev/null; then
  updates_needed=false
else
  updates_needed=true
fi
check_result "Update Performed" "[ $updates_needed = false ]"

# 9. Check Configuration Management Software (e.g., Ansible, Puppet, Chef)
config_mgmt_installed=$(rpm -qa | grep -E 'ansible|puppet|chef-server-core' | wc -l)
check_result "No Configuration Management Software" "[ $config_mgmt_installed -eq 0 ]"

# 10. Check if sos package is installed
sos_installed=$(rpm -qa | grep -c '^sos')
check_result "sos Package Installed" "[ $sos_installed -gt 0 ]"

# 11. Check connection to Red Hat CDN
ping -c4 cdn.redhat.com &>/dev/null
if [ $? -eq 0 ]; then
  echo -e "Connection to Red Hat CDN: \e[32mPASS\e[0m"
else
  echo -e "Connection to Red Hat CDN: \e[31mFAIL\e[0m"
  echo "There may be a proxy server involved between this $(hostname -s) server and the Red Hat CDN."
  all_checks_passed=false
fi

# Final result
if $all_checks_passed; then
  echo -e "\nOverall System Checks: \e[32mPASS\e[0m"
else
  echo -e "\nOverall System Checks: \e[31mFAIL\e[0m"
  exit 1
fi

