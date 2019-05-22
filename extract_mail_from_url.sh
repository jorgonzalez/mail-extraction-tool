#!/bin/bash
#
#	Author:		Jorge González
#
# 	Description:	Script to scrap emails from URLs given an ARG list in TVS format.
#
#	Version:	0.7
#
#	Modifications:	v0.1; first version.
#			v0.2; Add MacOS support.
#			v0.3; Scrap "text(at)text.domain" and "text (at) text.domain" mails.
#			v0.4; Scrap "text[at]text[dot]domain" mails.
#			v0.5; Add a filter list to remove unwanted words from emails.
#			v0.6; Verify and only allow '.tvs' entry files.
#			v0.7; Verify if FILTER_LIST_FILE file exists; add timeoutBin (timeout/gtimout) for Linux/MacOs.
#			v0.8; Added support for CYGWIN.
#
#	Future imprv.:	Preview.
#			Option to have the secondaries scenes on the right.
#

#Some variables
version=0.8

#Total download time for a website; might not be enough for some websites
TIMEOUT=120
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

#Get the extension of the file, we only work with '.tvs'
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

i=1
while read LINE; do
	if [[ "${EXT}" != ".tsv" ]]; then
		echo "ERROR: entry list file must be in format of tabs separated values '.tvs' (extension)"
		exit 1
	elif [[ "${EXT}" == ".tsv" ]]; then
		WEBSITE=$(echo "${LINE}" | awk -F"\t" '{print $1}' | tr -d "*\"")
		URL=$(echo "${LINE}" | awk -F"\t" '{print $2}' | sed 's/\r//')
	fi

	echo "Processing record ${i}/${N_OF_RECORDS} (${WEBSITE})..."

	if [[ ! -z "${URL}" && "$URL" != "http" ]]; then
		rm ${TMP_FILE} 2>/dev/null
		if [[ "${LINUX}" -eq 1 || "${CYGWIN}" -eq 1 ]]; then
			timeoutBin=$(which timeout)
			${timeoutBin} ${TIMEOUT} wget -t ${RETRIES} -r -l 2 -qO ${TMP_FILE} ${URL}
			EMAIL_LIST_1=$(grep -ahrio "\b[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | tr "\n" ", ")
			EMAIL_LIST_2=$(grep -ahrio "\b[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_3=$(grep -ahrio "\b[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_4=$(grep -ahrio "\b[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
		elif [[ "${MACOS}" -eq 1 ]]; then
			timeoutBin=$(which gtimeout)
			${timeoutBin} wget -r -l 2 -qO -T ${TIMEOUT} -t ${RETRIES} ${TMP_FILE} ${URL}
			EMAIL_LIST_1=$(grep -ahrio "[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | tr "\n" ", ")
			EMAIL_LIST_2=$(grep -ahrio "[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_3=$(grep -ahrio "[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_4=$(grep -ahrio "[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
		fi
		EMAIL_LIST=$(echo ${EMAIL_LIST_1} ${EMAIL_LIST_2} ${EMAIL_LIST_3} ${EMAIL_LIST_4} | tr '[:upper:]' '[:lower:]' | tr -d " " | tr "," "\n" | sort -u | grep -Ev "${FILTER_LIST}" | tr "\n" "," | cut -b 2- | rev | cut -b 2- | rev)
	fi

	echo -e "${WEBSITE}\t${URL}\t${EMAIL_LIST}" >> ${OUTPUT_FILE}
	rm ${TMP_FILE} 2>/dev/null
	let i=${i}+1
done < ${WEBSITE_LIST_FILE}

echo -e "\n================================================================================"
echo -e "DONE!"
