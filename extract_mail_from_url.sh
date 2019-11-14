#!/bin/bash
#
#	Author:		Jorge González
#
# 	Description:	Script to scrap emails from URLs given an ARG list in TVS format.
#
#	Version:	0.12
#
#	Modifications:	v0.1; first version.
#			v0.2; Add MacOS support.
#			v0.3; Scrap "text(at)text.domain" and "text (at) text.domain" mails.
#			v0.4; Scrap "text[at]text[dot]domain" mails.
#			v0.5; Add a filter list to remove unwanted words from emails.
#			v0.6; Verify and only allow '.tvs' entry files.
#			v0.7; Verify if FILTER_LIST_FILE file exists; add timeoutBin (timeout/gtimout) for Linux/MacOs.
#			v0.8; Added support for CYGWIN.
#			v0.9; Added UID.
#			v0.10; Fixed wrong WEBUID output var; remove first line of input file if header.
#			v0.11; Scrap "text[ät]text.domain", "text [at] text.domain", "text [at] text [punkt] domain", "text(at)text(dot)domain" and "text [at] text [dot] domain" mails.
#			v0.12; Scrap whole domain and not only the given subdomain.
#
#	Future imprv.:	
#

#Some variables
version=0.12

#Total download time for a website; might not be enough for some websites
TIMEOUT=180
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

#Remove the first line of the input file if it's the header
if [[ $(head -n 1 ${WEBSITE_LIST_FILE} | grep http | wc -l) -ne 1 ]]; then
	sed '1d' ${WEBSITE_LIST_FILE} -i
fi

i=1
while read LINE; do
	if [[ "${EXT}" != ".tsv" ]]; then
		echo "ERROR: entry list file must be in format of tabs separated values '.tvs' (extension)"
		exit 1
	elif [[ "${EXT}" == ".tsv" ]]; then
		WEBUID=$(echo "${LINE}" | awk -F"\t" '{print $1}')
		WEBSITE=$(echo "${LINE}" | awk -F"\t" '{print $2}' | tr -d "*\"")
		URL=$(echo "${LINE}" | awk -F"\t" '{print $3}' | sed 's/\r//')
		DOMAIN=$(expr match "${URL}" '.*\.\(.*\..*\)' | awk -F"/" '{print $1}')
	fi

	echo "Processing record ${i}/${N_OF_RECORDS} (${WEBSITE})..."

	if [[ ! -z "${URL}" && "${URL}" != "http" ]]; then
		rm ${TMP_FILE} 2>/dev/null
		if [[ "${LINUX}" -eq 1 || "${CYGWIN}" -eq 1 ]]; then
			timeoutBin=$(which timeout)
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
