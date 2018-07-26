#!/bin/bash
# 
# Script to convert the Telise Technical Planning Calender to a standard iCal format
# Made by: Boris Aelen
# Created on: 11 January 2013
# Last Modifed: 19 Maart
# Version: 0.3
#
# usage: ./telise2ical.sh -u <username> -p <password> -e <engineer> | -o[ffline]
#
#

USERNAME=nl420
PASSWORD=$USERNAME
ENGINEER=$USERNAME
FILENAME=`pwd`/agenda_$ENGINEER.ics

usage(){
        echo -e "";
        echo -e "Usage: $PROG -u <username> -p <password> -e <engineer> | --offline";
        echo -e "";
        echo -e "-u\tThe (NLXXX) username you have in Telise";
        echo -e "-p\tThe password for your Telise useraccount";
        echo -e "-e\tThe (NLXXX) name of the Engineer";
        echo -e "-o\tOffline, reuse the current data from Telise (no wget)";
        echo -e "[-?]\tShow this help";
        echo -e "";
        exit 0;
}

collect_data(){
	if [ ! -e tmp ]; then mkdir tmp; cd tmp; else rm -rf tmp; mkdir tmp; cd tmp; fi
	
	echo -ne "\E[00mLogging in to Telise as $USERNAME ... \t\t\t\t\t";
	wget --keep-session --save-cookies=telise.cookie "http://ambiorix.telindus.intra/scripts/cgiip.exe/WService=Telise/telise.r?lv-button=submit&lvdatabase=tnl&lvname=$USERNAME&lv-password=$PASSWORD" -O /dev/null --quiet;
	if [ $? -eq 0 ] ; then echo -e "\E[32m[SUCCES]"; else echo -e "\E[31m[FAILED]"; echo -e "\E[00m"; exit 1; fi;
 
	echo -ne "\E[00mGathering the Technical Planning for $ENGINEER ... \t\t\t\t";
	wget --load-cookies=telise.cookie "http://ambiorix.telindus.intra/scripts/cgiip.exe/WService=Tnl/TechOverview-v8.r?lv-button=Search&searchName=01/01/13&search-name-a=DNL01&search-name-b=$ENGINEER&totalDays=365" -O agenda.html --quiet;
	if [ $? -eq 0 ] ; then echo -e "\E[32m[SUCCES]"; else echo -e "\E[31m[FAILED]"; echo -e "\E[00m"; exit 1; fi;
 
	echo -en "\E[00mGoing to get all the entries from the Technial Planning for $ENGINEER ... \t";
	if [ ! -e entries ]; then mkdir entries; else rm -rf entries; mkdir entries; fi
	for x in `cat agenda.html  | grep submitForm | grep "Update Record" | cut -d"," -f 3 | sed "s/'//g"`; do
		wget --load-cookies=telise.cookie "http://ambiorix.telindus.intra/scripts/cgiip.exe/WService=Tnl/TechCal-Add-v8-plan.r?lvTech=$ENGINEER&lvUpdate=Yes&lvRecid=$x&search_name_a=DNL01" -O entries/$x.html --quiet
	done;
	if [ $? -eq 0 ] ; then echo -e "\E[32m[SUCCES]"; else echo -e "\E[31m[FAILED]"; echo -e "\E[00m"; exit 1; fi
	cd ..
}


generate_ical(){
	cd tmp;
	echo -en "\E[00mGenerating iCalendar for $ENGINEER ... \t\t\t\t\t"

	echo "BEGIN:VCALENDAR" > $FILENAME
	echo "PRODID:-//Telindus//NONSGML Telise Events V1.0//EN" >> $FILENAME
	echo "X-WR-CALNAME:Telise planning van Boris Aelen" >> $FILENAME
	echo "X-PUBLISHED-TTL:PT1H" >> $FILENAME
	echo "X-ORIGINAL-URL:http://ambiorix.telindus.intra/" >> $FILENAME
	echo "VERSION:2.0" >> $FILENAME
	echo "CALSCALE:GREGORIAN" >> $FILENAME
	echo "METHOD:PUBLISH" >> $FILENAME
	
	for x in entries/*; do 
		#echo -ne "processing $x..."
		desc=`cat $x | grep lvdescription |  sed -n -r 's/.*+VALUE="([^"]+)".*/\1/gp'`
		fromdate=`cat $x | grep lvFromDate |  sed -n -r 's/.*+VALUE="([^"]+)".*/\1/gp'`
		todate=`cat $x | grep lvToDate |  sed -n -r 's/.*+VALUE="([^"]+)".*/\1/gp'`
		starttime=`cat $x | grep lv_start_time |  sed -n -r 's/.*+VALUE="([^"]+)".*/\1/gp'`
		starttime=`TZ="UTC" date --date="TZ=\"Europe/Amsterdam\" $starttime" +%R`
		endtime=`cat $x | grep lv_end_time |  sed -n -r 's/.*+VALUE="([^"]+)".*/\1/gp'`
		endtime=`TZ="UTC" date --date="TZ=\"Europe/Amsterdam\" $endtime" +%R`
		if [ $endtime = "00:00" ]; then endtime="23:59"; fi
		DTSTART=`echo $fromdate | awk -F"/" '{ print $3 $2 $1 "T"}'` 
		DTSTART="$DTSTART`echo -n $starttime | awk -F":" '{ print $1 $2 "00Z" }'`"
		DTEND=`echo $todate | awk -F"/" '{ print $3 $2 $1 "T"}'` 
		DTEND="$DTEND`echo -n $endtime | awk -F":" '{ print $1 $2 "00Z" }'`"
		x2=`echo $x |  sed -n -r 's/.*+entries\/([^"]+)\..*/\1/gp'`
		echo "BEGIN:VEVENT" >> $FILENAME
		echo "DTSTAMP:`date +%Y%m%d`T`date +%H%M%S`Z" >> $FILENAME
		echo "LAST-MODIFIED:`date +%Y%m%d`T`date +%H%M%S`Z" >> $FILENAME
		echo "CREATED:`date +%Y%m%d`T`date +%H%M%S`Z" >> $FILENAME
		echo "SEQUENCE:$x" >> $FILENAME
		echo "ORGANIZER;CN=NL_Planning:MAILTO:nl_planning@telindus-isit.nl" >> $FILENAME
		echo "DTSTART:$DTSTART" >> $FILENAME
		echo "DTEND:$DTEND" >> $FILENAME
		echo "UID:$x" >> $FILENAME
		echo "SUMMARY:$desc" >> $FILENAME
#		echo "LOCATION: De Locatie" >> $FILENAME
		echo "URL: http://ambiorix.telindus.intra/scripts/cgiip.exe/WService=Tnl/TechCal-Add-v8-plan.r?lvTech=$ENGINEER&lvUpdate=Yes&lvRecid=$x2&search_name_a=DNL01" >> $FILENAME
#		echo "DESCRIPTION: Hier mag een zo uitgebreid mogelijke descriptie komen van de het evenement, commas moeten wel geescaped worden" >> $FILENAME
#		echo "CLASS:PUBLIC" >> $FILENAME
		echo "STATUS:Confirmed" >> $FILENAME
#		echo "PARTSTAT:Tentative" >> $FILENAME
		echo "END:VEVENT" >> $FILENAME
	done
	echo "END:VCALENDAR" >> $FILENAME

	if [ $? -eq 0 ]; then
		echo -e "\E[32m[SUCCES]";
		echo
		echo -e "\E[00miCalendar has been successfully genereated with filename $FILENAME";
	else
		echo -e "\E[31m[FAILED]"
		echo -e "\E[00m"
		exit 1
	fi
	cd ..
	exit 0 
}

while getopts "e:u:p:o?" 1> /dev/null ARG
do
        case $ARG in
                u)              USERNAME=$OPTARG
                                ;;
                p)              PASSWORD=$OPTARG
                                ;;
                e)              ENGINEER=$OPTARG
                                ;;
                o)	        generate_ical
                                ;;
                ?)              usage
                                exit 1
                                ;;
        esac
done

collect_data
generate_ical
