#!/bin/bash

TIMEOUT=40
RETRIES=3
SYSTEM=$(uname -a)
LINUX=$(echo ${SYSTEM} | grep -i linux | wc -l)
MACOS=$(echo ${SYSTEM} | grep -i darwin | wc -l)

BUSINESS_LIST_FILE=${@}
FILTER_LIST_FILE="filter_list"
FILTER_LIST=$(cat ${FILTER_LIST_FILE} | tr "\n" "|" | rev | cut -b 2- | rev)
EXT=$(echo ${BUSINESS_LIST_FILE} | rev | cut -b -4 | rev)
TMP_FILE="website_"${BUSINESS_LIST_FILE}
OUTPUT_FILE=${BUSINESS_LIST_FILE}"_WITH_MAILS.tsv"
rm ${OUTPUT_FILE} 2>/dev/null

N_OF_RECORDS=$(wc -l ${BUSINESS_LIST_FILE} | awk '{print $1}')

if [[ -z "${BUSINESS_LIST_FILE}" ]]; then
	echo "ERROR: business list file cannot be empty"
	exit 1
elif [[ ! -f "${BUSINESS_LIST_FILE}" ]]; then
	echo "ERROR: ${BUSINESS_LIST_FILE} is not a valid file"
	exit 1
fi

i=1
while read LINE; do
	if [[ "${EXT}" != ".tsv" ]]; then
		echo "ERROR: entry list file must be in format of tabs separated values '.tvs' (extension)"
		exit 1
	elif [[ "${EXT}" == ".tsv" ]]; then
		BUSINESS_NAME=$(echo "${LINE}" | awk -F"\t" '{print $1}' | tr -d "*\"")
		URL=$(echo "${LINE}" | awk -F"\t" '{print $2}' | sed 's/\r//')
	fi

	echo "Processing record ${i}/${N_OF_RECORDS} (${BUSINESS_NAME})..."

	if [[ ! -z "${URL}" && "$URL" != "http" ]]; then
		rm ${TMP_FILE} 2>/dev/null
		if [[ "${LINUX}" -eq 1 ]]; then
			timeout ${TIMEOUT} wget -t ${RETRIES} -r -l 2 -qO ${TMP_FILE} ${URL}
			EMAIL_LIST_1=$(grep -ahrio "\b[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | tr "\n" ", ")
			EMAIL_LIST_2=$(grep -ahrio "\b[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_3=$(grep -ahrio "\b[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_4=$(grep -ahrio "\b[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}\+\b" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
		elif [[ "${MACOS}" -eq 1 ]]; then
			wget -r -l 2 -qO -T ${TIMEOUT} -t ${RETRIES} ${TMP_FILE} ${URL}
			EMAIL_LIST_1=$(grep -ahrio "[a-z0-9.-]\+@[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | tr "\n" ", ")
			EMAIL_LIST_2=$(grep -ahrio "[a-z0-9.-]*\s(at)*\s[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/ (at) /@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_3=$(grep -ahrio "[a-z0-9.-]\+(at)[a-z0-9.-]\+\.[a-z]\{2,4\}" ${TMP_FILE} | sed 's/(at)/@/g' | sort -u | tr "\n" ", ")
			EMAIL_LIST_4=$(grep -ahrio "[a-z0-9.-]\+\[at\][a-z0-9.-]\+\[dot\][a-z]\{2,4\}" ${TMP_FILE} | sed 's/\[at\]/@/g' | sed 's/\[dot\]/./' | sort -u | tr "\n" ", ")
		fi
		EMAIL_LIST=$(echo ${EMAIL_LIST_1} ${EMAIL_LIST_2} ${EMAIL_LIST_3} ${EMAIL_LIST_4} | tr '[:upper:]' '[:lower:]' | tr -d " " | tr "," "\n" | sort -u | grep -Ev "${FILTER_LIST}" | tr "\n" "," | cut -b 2- | rev | cut -b 2- | rev)
	fi

	echo -e "${BUSINESS_NAME}\t${URL}\t${EMAIL_LIST}" >> ${OUTPUT_FILE}
	rm ${TMP_FILE} 2>/dev/null
	let i=${i}+1
done < ${BUSINESS_LIST_FILE}

echo -e "\n================================================================================"
echo -e "DONE!"
