#!/bin/bash

# Define color codes
RED='\033[1;31m'
GRN='\033[1;32m'
BLU='\033[1;34m'
YEL='\033[1;33m'
PUR='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m'

# Display header
echo -e "${CYAN}Bypass MDM By Assaf Dori (assafdori.com)${NC}"
echo ""

# Prompt user for choice
PS3='Please enter your choice: '
options=("Bypass MDM from Recovery" "Reboot & Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Bypass MDM from Recovery")
            # Bypass MDM from Recovery
            echo -e "${YEL}Bypass MDM from Recovery"
            if [ -d "/Volumes/Macintosh HD - Data" ]; then
                diskutil rename "Macintosh HD - Data" "Data"
            fi

            # Create Temporary User
            echo -e "${NC}Create a Temporary User"
            read -p "Enter Temporary Fullname (Default is 'User'): " realName
            realName="${realName:=User}"
            read -p "Enter Temporary Username (Default is 'User'): " username
            username="${username:=User}"
            read -p "Enter Temporary Password (Default is ''): " passw
            passw="${passw:=}"

            # Create User
            dscl_path='/Volumes/Data/private/var/db/dslocal/nodes/Default'
            echo -e "${GREEN}Creating Temporary User"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UserShell "/bin/zsh"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" RealName "$realName"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" UniqueID "501"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" PrimaryGroupID "20"
            mkdir "/Volumes/Data/Users/$username"
            dscl -f "$dscl_path" localhost -create "/Local/Default/Users/$username" NFSHomeDirectory "/Users/$username"
            dscl -f "$dscl_path" localhost -passwd "/Local/Default/Users/$username" ""
            dscl -f "$dscl_path" localhost -append "/Local/Default/Groups/admin" GroupMembership $username

            # Enable auto-login
            # --- Auto-login setup ---
            DAT="/Volumes/Data"
            PLIST="$DAT/Library/Preferences/com.apple.loginwindow"
            KCP="$DAT/private/etc/kcpassword"

            # 1) point loginwindow at the account
            /usr/bin/defaults write "$PLIST" autoLoginUser "$username"
            /usr/bin/defaults write "$PLIST" DisableAutoLogin -bool false

            # 2) write kcpassword for the entered password (handles blank too)
            #    Apple key sequence used for XOR
            KEY=(0x7d 0x89 0x52 0x23 0xd2 0xbc 0xdd 0xea 0xa3 0xb9 0x1f)

            gen_kcpassword() {
              local pwd="$1"
              # blank password: kcpassword is just the key bytes
              if [ -z "$pwd" ]; then
                printf '\x7d\x89\x52\x23\xd2\xbc\xdd\xea\xa3\xb9\x1f'
                return
              fi
              local -a bytes=()
              # build bytes from password plus trailing 0x00
              local i ch ord
              for ((i=0; i<${#pwd}; i++)); do
                ch="${pwd:i:1}"
                printf -v ord "%d" "'$ch"
                bytes+=($ord)
              done
              bytes+=(0)  # null terminator

              # XOR with key repeated
              local out=() k=0
              for ((i=0; i<${#bytes[@]}; i++)); do
                k=$(( i % ${#KEY[@]} ))
                out+=($(( bytes[i] ^ KEY[k] )))
              done

              # emit as raw bytes
              for b in "${out[@]}"; do printf "\\x%02x" "$b"; done
            }

            umask 077
            gen_kcpassword "$passw" > "$KCP"
            /usr/sbin/chown 0:0 "$KCP"
            /bin/chmod 600 "$KCP"

            echo -e "${GRN}Auto-login configured for $username${NC}"

            # Block MDM domains
            echo "0.0.0.0 deviceenrollment.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
            echo "0.0.0.0 mdmenrollment.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
            echo "0.0.0.0 iprofiles.apple.com" >>/Volumes/Macintosh\ HD/etc/hosts
            echo -e "${GRN}Successfully blocked MDM & Profile Domains"
            
            # Remove configuration profiles
            touch /Volumes/Data/private/var/db/.AppleSetupDone
            rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
            rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
            touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
            touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound

            echo -e "${GRN}MDM enrollment has been bypassed!${NC}"
            echo -e "${NC}Exit terminal and reboot your Mac.${NC}"
            break
            ;;
        "Disable Notification (SIP)")
            # Disable Notification (SIP)
            echo -e "${RED}Please Insert Your Password To Proceed${NC}"
            sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
            sudo rm /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
            sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
            sudo touch /var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
            break
            ;;
        "Disable Notification (Recovery)")
            # Disable Notification (Recovery)
            rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigHasActivationRecord
            rm -rf /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordFound
            touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigProfileInstalled
            touch /Volumes/Macintosh\ HD/var/db/ConfigurationProfiles/Settings/.cloudConfigRecordNotFound
            break
            ;;
        "Check MDM Enrollment")
            # Check MDM Enrollment
            echo ""
            echo -e "${GRN}Check MDM Enrollment. Error is success${NC}"
            echo ""
            echo -e "${RED}Please Insert Your Password To Proceed${NC}"
            echo ""
            sudo profiles show -type enrollment
            break
            ;;
        "Reboot & Exit")
            # Reboot & Exit
            echo "Rebooting..."
            reboot
            break
            ;;
        *) echo "Invalid option $REPLY" ;;
    esac
done
