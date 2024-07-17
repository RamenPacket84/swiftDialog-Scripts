#!/bin/bash
# Use swiftDialog to notify Azure AD users of password expiration
# Author: Ramen Packet
# Version 1.0

# This script will not work without installing Bart Reardon's swiftDialog which can be found here: https://github.com/swiftDialog/swiftDialog

# Change the number on line 20 to match org password expiration policy. 
# Change the number on line 31 to configure when the user will see the SwiftDialog notification. e.g. 75 - 65 = notification begins 10 days before expiration.

loggedinuser=$( /bin/echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
accountcreationdate=$( stat -x /Users/$loggedinuser | grep "Birth" | awk '{print $3 " " $4 " " $6}')
uid=$(id -u "$loggedinuser")
passwordlastreset=$(date -r $(dscl . -read /Users/$loggedinuser accountPolicyData | tail -n +2 | plutil -extract passwordLastSetTime xml1 -o - -- - | sed -n "s/<real>\([0-9]*\).*/\1/p") | awk '{print $2 " " $3 " " $6}')
todaysdate=$(date -r $(date +%s) | awk '{print $2 " " $3 " " $6}')
passlastsetconvertdate=$(date -jf "%b %d %Y" "$passwordlastreset" +"%s")
currentconvertdate=$(date "+%s")
datediff=$(($currentconvertdate - $passlastsetconvertdate))
days_ago=$((datediff / (60 * 60 * 24)))
daysuntilexp=$((75 - $days_ago))
dialogpath=/usr/local/bin/dialog

#FUNCTIONS
# Notify the user that their password is expiring soon
notify(){
    launchctl asuser $uid $dialogpath --notification --title "Reminder" --message "Your password will expire in $daysuntilexp days."
}

# Calculate days to fire the notification. This will notify the user 10 days before expiration
calc(){
    if [[ $days_ago -ge 65 ]]; then
    /bin/echo "User needs to be notified. Password was last changed $days_ago days ago. Call the notify function."
    notify  
        else
    /bin/echo "It is not yet time to notify the user. Exit script."
    exit 0
    fi
} 

#BEGIN SCRIPT
# If the user has not changed their pasword at least one time with Jamf Connect on this device exit the script, since the local password 'last changed date' may not match the AAD password expiration date
if [[ $passwordlastreset == $accountcreationdate ]]; then
    /bin/echo "User has not changed their password on this mac at lease one time. $passwordlastreset may not match AAD last password date change time. Exit."
    exit 0
else 
    /bin/echo "User has changed their password at least one time. Resuming..."
fi

# Confirm swiftDialog is installed
if [[ -f $dialogpath ]]; then
    /bin/echo "swiftDialog is installed. Resume."
    /bin/echo ""
    # Log date of last password change.
    /bin/echo "$passwordlastreset is the date of the last password change."
    /bin/echo ""
    # Log the number of days until password expires
    /bin/echo "Password will expire in $daysuntilexp days."
    /bin/echo ""
    # Call the calc function
    calc
else 
    /bin/echo "swiftDialog is not installed. Exit."
    exit 0
fi