#!/bin/bash
# Reads the call log from your local fritzbox and checks the number agains the tellows service
#
# Only tested with a Fritzbox 7020! 


# Here goes the ip address or the hostname
fbox="<hn>"
# And here the login password of your fbox gui
PASSWD="<pwd>"
KNOWNNUMBERS_DIR="/var/cache/fboxcalls"
KNOWNNUMBERS="$KNOWNNUMBERS_DIR/known_numbers"

if [ ! -d $KNOWNNUMBERS_DIR ]
then
  mkdir -p $KNOWNNUMBERS_DIR
fi


if [ ! -f /tmp/fboxsid ]; then
    touch /tmp/fboxsid
fi
ssid=$(cat /tmp/fboxsid)

##check if current login is valid else generate session id 
result=$(curl -s "http://$fbox/login_sid.lua?sid=$ssid" | grep -c "0000000000000000")

if [ $result -gt 0 ]; then
        #echo "Login notwendig"
        challenge=$(curl -s http://$fbox/login_sid.lua |  grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
        hash=$(echo -n "$challenge-$PASSWD" |sed -e 's,.,&\n,g' | tr '\n' '\0' | md5sum | grep -o "[0-9a-z]\{32\}")
        curl -s "http://$fbox/login_sid.lua" -d "response=$challenge-$hash" | grep -o "<SID>[a-z0-9]\{16\}" |  cut -d'>' -f 2 > /tmp/fboxsid
fi
ssid=$(cat /tmp/fboxsid)
##login function ende

DATE=`date +%d.%m.%y`
curl -s "http://$fbox/fon_num/foncalls_list.lua?sid=$ssid&csv=" > /tmp/last_calls.txt
curl -s "http://$fbox/fon_num/foncalls_list.lua?sid=$ssid&csv=" | egrep "^1;|^2;" | grep -v "Dead Drop" | grep -v "Unbekannt" | while read call
do
    entryname=`echo $call | cut -d";" -f3`
    if [ "$entryname" != "" ]
    then
        continue
    fi
    number=`echo $call | cut -d";" -f4`
    calldate=`echo $call | cut -d";" -f2`
    egrep -q "^$number:" $KNOWNNUMBERS
    if [ $? != 0 ]
    then
        score=`lynx -dump http://www.tellows.de/num/$number | grep '\]Tellows Score' | awk '{print $3}'`
        epoch=`date +%s`
        echo "$number:$score:$epoch" >> $KNOWNNUMBERS
    else
        score=`egrep "^$number:" $KNOWNNUMBERS | cut -d: -f2`
    fi
    echo -n -e "$calldate\t\t$number\t\tScore $score"
    if [ "$score" -gt 6 ]
        then echo -e "\t - SPAM!"
    else
        echo
    fi
done

