#!/bin/bash
#
#	Author:		Jorge González
#
# 	Description:	Script to scrap emails from URLs given an ARG list in TSV format.
#
#	Version:	0.16
#
#	Modifications:	v0.1; first version.
#			v0.2; Add MacOS support.
#			v0.3; Scrap "text(at)text.domain" and "text (at) text.domain" mails.
#			v0.4; Scrap "text[at]text[dot]domain" mails.
#			v0.5; Add a filter list to remove unwanted words from emails.
#			v0.6; Verify and only allow '.tsv' entry files.
#			v0.7; Verify if FILTER_LIST_FILE file exists; add timeoutBin (timeout/gtimout) for Linux/MacOs.
#			v0.8; Added support for CYGWIN.
#			v0.9; Added UID.
#			v0.10; Fixed wrong WEBUID output var; remove first line of input file if header.
#			v0.11; Scrap "text[ät]text.domain", "text [at] text.domain", "text [at] text [punkt] domain", "text(at)text(dot)domain" and "text [at] text [dot] domain" mails.
#			v0.12; Scrap whole domain and not only the given subdomain.
#			v0.13; Crawl websites that have been redirected (301).
#			v0.14; Fix website processing when URL is non ASCII.
#			v0.15; Add TIMEOUT as an ENV VAR.
#			v0.16; Avoid downloading home file (e.g.: index.html) when asking for headers.
#
#	Future imprv.:
#

#Some variables
version=0.16

#Total download time for a website; might not be enough for some websites
if [[ -z ${TIMEOUT} ]]; then
	TIMEOUT=180
fi
#Number of times to retry to download a website
RETRIES=3

#We need to know if we are running under linux or macos
SYSTEM=$(uname -a)
LINUX=$(echo ${SYSTEM} | grep -i linux | wc -l)
MACOS=$(echo ${SYSTEM} | grep -i darwin | wc -l)
CYGWIN=$(echo ${SYSTEM} | grep -i cygwin | wc -l)

#The weblist entry file is ARG
WEBSITE_LIST_FILE=${@}

#If there is a filter list, populate it
FILTER_LIST_FILE="filter_list"
if [[ -f ${FILTER_LIST_FILE} ]]; then
	FILTER_LIST=$(cat ${FILTER_LIST_FILE} | tr "\n" "|" | rev | cut -b 2- | rev)
else
	FILTER_LIST=NULL
fi

#Get the extension of the file, we only work with '.tsv'
EXT=$(echo ${WEBSITE_LIST_FILE} | rev | cut -b -4 | rev)
TMP_FILE="website_"${WEBSITE_LIST_FILE}
OUTPUT_FILE=${WEBSITE_LIST_FILE}"_WITH_MAILS.tsv"
rm ${OUTPUT_FILE} 2>/dev/null

#Total number of records in the file
N_OF_RECORDS=$(wc -l ${WEBSITE_LIST_FILE} | awk '{print $1}')

#Only allow '.tsv' file format
if [[ -z "${WEBSITE_LIST_FILE}" ]]; then
	echo "ERROR: website list file cannot be empty"
	exit 1
elif [[ ! -f "${WEBSITE_LIST_FILE}" ]]; then
	echo "ERROR: ${WEBSITE_LIST_FILE} is not a valid file"
	exit 1
fi

#Function to check if the domain is owned or is a subdomain of a known web service.
function check_domain {
	DOMAIN=${1}
	DOMAIN_CHECK=$(echo ${DOMAIN} | grep -E ".business.|.eatbu.|.jimdo.|.webnode.|.tumblr.|.google.|.blogspot.|.wixsite.|.metro.|.wordpress." | wc -l)
}


#Remove the first line of the input file if it's the header
if [[ $(head -n 1 ${WEBSITE_LIST_FILE} | grep http | wc -l) -ne 1 ]]; then
	sed '1d' ${WEBSITE_LIST_FILE} -i
fi

i=1
while read LINE; do
	if [[ "${EXT}" != ".tsv" ]]; then
		echo "ERROR: entry list file must be in format of tabs separated values '.tsv' (extension)"
		exit 1
	elif [[ "${EXT}" == ".tsv" ]]; then
		WEBUID=$(echo "${LINE}" | awk -F"\t" '{print $1}')
		WEBSITE=$(echo "${LINE}" | awk -F"\t" '{print $2}' | tr -d "*\"")
		URL=$(echo "${LINE}" | awk -F"\t" '{print $3}' | sed 's/\r//')
		DOMAIN=$(echo ${URL} | sed -E -e 's_.*://([^/@]*@)?([^/:]+).*_\2_')
		check_domain ${DOMAIN}
		if [[ ${DOMAIN_CHECK} -eq 0 ]]; then
			DOMAIN_FIX=$(expr match "${DOMAIN}" '.*\.\(.*\..*\)' | awk -F"/" '{print $1}')
			if [[ -z ${DOMAIN_FIX} ]]; then
				DOMAIN=$(expr match ${DOMAIN} '\(.*\..*\)')
			else
				DOMAIN=${DOMAIN_FIX}
			fi
		fi
	fi

	echo "Processing record ${i}/${N_OF_RECORDS} (${WEBSITE})..."

	if [[ ! -z "${URL}" && "${URL}" != "http" ]]; then
		rm ${TMP_FILE} 2>/dev/null
		if [[ "${LINUX}" -eq 1 || "${CYGWIN}" -eq 1 ]]; then
			timeoutBin=$(which timeout)
			#Check if the URL is the proper source: websites can be moved to another main domain (e.g. berghain.berlin -> berghain.de)
			URL_HEADERS=$(wget -q -S -O - ${URL} 2>&1 1>/dev/null)
			if [[ $(echo "${URL_HEADERS}" | grep "Moved Permanently" | wc -l) -eq 1 ]]; then
				NEW_DOMAIN=$(echo "${URL_HEADERS}" | grep -i "location: http" | awk '{print $2}' | tail -n 1)
				check_domain ${NEW_DOMAIN}
				if [[ ${DOMAIN_CHECK} -eq 0 ]]; then
					DOMAIN_FIX=$(expr match "${NEW_DOMAIN}" '.*\.\(.*\..*\)' | awk -F"/" '{print $1}')
					if [[ -z ${DOMAIN_FIX} ]]; then
						DOMAIN=$(expr match ${NEW_DOMAIN} '\(.*\..*\)')
					else
						DOMAIN=${DOMAIN_FIX}
					fi
				fi
			fi

			${timeoutBin} ${TIMEOUT} wget -t ${RETRIES} -rH -l 2 -D ${DOMAIN} -qO ${TMP_FILE} ${URL}
			#text@text.domain
			EMAIL_LIST_1=$(grep -ahrio "\b[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | tr "\n" ", ")
			#text (at) text.domain
			EMAIL_LIST_2=$(grep -ahrio "\b[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			#text(at)text.domain
			EMAIL_LIST_3=$(grep -ahrio "\b[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			#text[at]text[dot]domain
			EMAIL_LIST_4=$(grep -ahrio "\b[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
			#text[ät]text.domain
			EMAIL_LIST_5=$(grep -ahrio "\b[a-z0-9.-]\+\[ät\][a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/\[ät\]/@/g' | sort -u | tr "\n" ", ")
			#text [at] text.domain
			EMAIL_LIST_6=$(grep -ahrio "\b[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sort -u | tr "\n" ", ")
			#text [at] text [punkt] domain
			EMAIL_LIST_7=$(grep -ahrio "\b[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]*\s\[punkt\]*\s[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sed 's/ \[punkt\] /./' | sort -u | tr "\n" ", ")
			#text(at)text(dot)domain
			EMAIL_LIST_8=$(grep -ahrio "\b[a-z0-9.-]\+(at)[a-z0-9.-]\+(dot)[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/(at)/@/g' | sed 's/(dot)/./' | sort -u | tr "\n" ", ")
			#text at text.domain
			EMAIL_LIST_9=$(grep -ahrio "\b[a-z0-9.-]*\sat*\s[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ at /@/g' | sort -u | tr "\n" ", ")
			#text [at] text [dot] domain
			EMAIL_LIST_10=$(grep -ahrio "\b[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]*\s\[dot\]*\s[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sed 's/ \[dot\] /./' | sort -u | tr "\n" ", ")
		elif [[ "${MACOS}" -eq 1 ]]; then
			timeoutBin=$(which gtimeout)
			URL_HEADERS=$(wget -q -S -O - ${DOMAIN} 2>&1 | head -n 30)
			if [[ $(echo "${URL_HEADERS}" | grep "Moved Permanently" | wc -l) -eq 1 ]]; then
				NEW_DOMAIN=$(echo "${URL_HEADERS}" | grep "Location: " | awk '{print $2}' | tail -n 1)
				NEW_DOMAIN=$(expr match "${NEW_DOMAIN}" '.*\.\(.*\..*\)' | awk -F"/" '{print $1}')
				URL=$(echo ${URL} | sed 's/'${DOMAIN}'/'${NEW_DOMAIN}'/')
				DOMAIN=${NEW_DOMAIN}
			fi

			${timeoutBin} wget -rH -l 2 -qO -T ${TIMEOUT} -t ${RETRIES} -D ${DOMAIN} ${TMP_FILE} ${URL}
			#text@text.domain
			EMAIL_LIST_1=$(grep -ahrio "[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | tr "\n" ", ")
			#text (at) text.domain
			EMAIL_LIST_2=$(grep -ahrio "[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			#text(at)text.domain
			EMAIL_LIST_3=$(grep -ahrio "[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			#text[at]text[dot]domain
			EMAIL_LIST_4=$(grep -ahrio "[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
			#text[ät]text.domain
			EMAIL_LIST_5=$(grep -ahrio "[a-z0-9.-]\+\[ät\][a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/\[ät\]/@/g' | sort -u | tr "\n" ", ")
			#text [at] text.domain
			EMAIL_LIST_6=$(grep -ahrio "[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sort -u | tr "\n" ", ")
			#text [at] text [punkt] domain
			EMAIL_LIST_7=$(grep -ahrio "[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]*\s\[punkt\]*\s[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sed 's/ \[punkt\] /./' | sort -u | tr "\n" ", ")
			#text(at)text(dot)domain
			EMAIL_LIST_8=$(grep -ahrio "[a-z0-9.-]\+(at)[a-z0-9.-]\+(dot)[a-z]\{2,4\}" ${TMP_FILE} | sed 's/(at)/@/g' | sed 's/(dot)/./' | sort -u | tr "\n" ", ")
			#text at text.domain
			EMAIL_LIST_9=$(grep -ahrio "[a-z0-9.-]*\sat*\s[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ at /@/g' | sort -u | tr "\n" ", ")
			#text [at] text [dot] domain
			EMAIL_LIST_10=$(grep -ahrio "[a-z0-9.-]*\s\[at\]*\s[a-z0-9.-]*\s\[dot\]*\s[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ \[at\] /@/g' | sed 's/ \[dot\] /./' | sort -u | tr "\n" ", ")
		fi
		EMAIL_LIST=$(echo ${EMAIL_LIST_1} ${EMAIL_LIST_2} ${EMAIL_LIST_3} ${EMAIL_LIST_4} ${EMAIL_LIST_5} ${EMAIL_LIST_6} ${EMAIL_LIST_7} ${EMAIL_LIST_8} ${EMAIL_LIST_9} ${EMAIL_LIST_10} \
		| tr '[:upper:]' '[:lower:]' | tr -d " " | tr "," "\n" | sort -u | grep -Ev "${FILTER_LIST}" | tr "\n" "," | cut -b 2- | rev | cut -b 2- | rev)
	fi

	echo -e "${WEBUID}\t${WEBSITE}\t${URL}\t${EMAIL_LIST}" >> ${OUTPUT_FILE}
	rm ${TMP_FILE} 2>/dev/null
	let i=${i}+1
done < ${WEBSITE_LIST_FILE}

echo -e "\n================================================================================"
echo -e "DONE!"
