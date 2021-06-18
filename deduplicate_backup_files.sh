#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

#----------------------------------------------------------------------
#  Preliminary actions
#----------------------------------------------------------------------
WHICH=/usr/bin/which

#"quit" is to replace "exit 1" that avoid exit also the shell
quit() { kill -SIGINT $$; }
die() { echo "$@" 1>&2 ; quit; }

#===  FUNCTION  ================================================================
#         NAME:  getPathAndCheckInstall
#  DESCRIPTION:  Get the path of an application and check if it is installed.
#        USAGE:  $MYAPP_PATH=$(getPathAndCheckInstall myapp)
# PARAMETER  1:  myapp : application
# RETURN VALUE:  Absolute path of application
#===============================================================================
getPathAndCheckInstall() {
    #argument cannot be empty ==> die
    if [ -z "${1}" ]; then
        die "FATAL ERROR: Use function getPathAndCheckInstall with an argument"
    fi
    local application=${1}
    local APPLICATION_PATH=$(${WHICH} ${application})
    if [[ ! -x ${APPLICATION_PATH} ]]; then
        die "FATAL ERROR: ${application} is not installed"
    fi
    echo ${APPLICATION_PATH}
}

#----------------------------------------------------------------------
#  Get the path of all programs
#----------------------------------------------------------------------
CAT=$(getPathAndCheckInstall cat)
CUT=$(getPathAndCheckInstall cut)
ECHO=$(getPathAndCheckInstall echo)
MKDIR=$(getPathAndCheckInstall mkdir)
RM=$(getPathAndCheckInstall rm)
MKTEMP=$(getPathAndCheckInstall mktemp)

STAT=$(getPathAndCheckInstall stat)
FIND=$(getPathAndCheckInstall find)
MD5SUM=$(getPathAndCheckInstall md5sum)
UNIQ=$(getPathAndCheckInstall uniq)
WC=$(getPathAndCheckInstall wc)
SORT=$(getPathAndCheckInstall sort)
PRINTF=$(getPathAndCheckInstall printf)
NUMFMT=$(getPathAndCheckInstall numfmt)
GREP=$(getPathAndCheckInstall grep)
PYTHON=$(getPathAndCheckInstall python)
AWK=$(getPathAndCheckInstall awk)
BC=$(getPathAndCheckInstall bc)

DB_DIR=$(${MKTEMP} -d --suffix=".dedup")
DEDUP_INSTRUCTIONS=$(${MKTEMP} --suffix=".deduplicate_instructions.sh")
TEMPO_LIST_OF_FILES=$(${MKTEMP} --suffix=".deduptempfiles.txt")
TEMPO_LIST_OF_DIRS=$(${MKTEMP} --suffix=".deduptempdirs.txt")
#TEMPO_LIST_OF_INODES=$(${MKTEMP} --suffix=".deduptempinodes.txt")

#Simple functions:
#-----------------
getInodeOfFile() {
    ${ECHO} $(${STAT} -c "%i" -- "${1}")
}
getSizeOfFile() {
    ${ECHO} $(${STAT} -c "%s" -- "${1}")
}

now() {
  ${ECHO} "import time; print(time.time())" 2>/dev/null | ${PYTHON}
}

displaytime() {
  local T=$1
  local D=$(${ECHO} $T/60/60/24|${BC})
  local H=$(${ECHO} $T/60/60%24|${BC})
  local M=$(${ECHO} $T/60%60|${BC})
  local S=$(${ECHO} $T%60|${BC})
  [[ $D > 0 ]] && ${PRINTF} '%dj ' $D
  [[ $H > 0 ]] && ${PRINTF} '%dh ' $H
  [[ $M > 0 ]] && ${PRINTF} '%dm ' $M
  ${PRINTF} '%ss\n' $S
}
#===  FUNCTION  ================================================================
#         NAME:  echoWithFixedsize
#  DESCRIPTION:  Display a text with a fixed size (add spaces if necessary,
#                trucate too long texts)
#        USAGE:  echoWithFixedsize size "String_to_adjust"
#     EXAMPLES:  echoWithFixedsize 8 "This will be trucated to 8 characters"
#                echoWithFixedsize 100 "This will be completed up to 100 chars"
# PARAMETER  1:  size : Size of the desired string
# PARAMETER  2:  "String_to_adjust" : String to ajust size.
#===============================================================================
echoWithFixedsize() {
    #arguments cannot be empty ==> die
    if [[ -z "${2}" || -z "${1}" ]]; then
        die "FATAL ERROR: Bad number of arguments in function areHardlinked"
    fi
    #get parameters
    size=${1}
    shift
    string=$*
    #Complete string if necessary
    to_display=$(${PRINTF} "%-${size}s" "${string}")
    #cut string if necessary
    ${ECHO} "${to_display:0:${size}}"
}

#===  FUNCTION  ================================================================
#         NAME:  usage
#  DESCRIPTION:  Display syntax to use the program
#===============================================================================
usage() {
    ${ECHO} "Deduplicate backup files by Hervé Suaudeau (GPL v3)"
    ${ECHO}
    ${ECHO} "Usage: $0 [OPTION] DIRECTORY_TO_DEDUPLICATE"
    ${ECHO}
    ${ECHO} "Options:"
    ${ECHO} " -s, --silent, --daemon   Do not print anything and lauch deduplicate script"
    ${ECHO} "                          after analysis."
    ${ECHO} " -f, --fast               Do a fast analysis (ignore files equal or"
    ${ECHO} "                          less than 10k)"
    ${ECHO} " -m NUM, --min_size NUM   Ignore files equal or less than NUM bytes."
    ${ECHO}
    ${ECHO} "Examples:"
    ${ECHO} "         $0 dir/subdir/backup_todeduplicate"
    ${ECHO} "         $0 --min_size 1024 dir/subdir/backup_todeduplicate_bigger_files"
    ${ECHO} "         $0 --silent dir/subdir/backup_todeduplicate_automatically"
}

echo_if_not_silent() {
  if [[ "${SILENT}" = false ]] ; then
    ${ECHO} "$*"
  fi
}
#===========================================================================
# STEP 0: Display warning and get parameters
#===========================================================================
SILENT=false
MIN_SIZE_OF_FILES="+0"

while [[ $# -gt 1 ]]
do
key="${1}"
case ${key} in
    -s|--silent|--daemon)
    SILENT=true
    ;;

    -f|--fast)
    MIN_SIZE_OF_FILES="+10240c"
    ;;

    -m|--min_size)
    if [[ "$2" -eq "$2" ]] 2>/dev/null
    then
      #this is an integer
      if [[ "$2"  -gt 0 ]]; then
        #it is positive
        MIN_SIZE_OF_FILES="+${2}c"
      fi
    fi
    shift # past argument
    ;;

    *)
      # unknown option
      usage
      die "FATAL ERROR: Bad arguments."
    ;;
esac
shift # past argument or value
done

#arguments cannot be empty ==> die
readonly ARGUMENTS="$@"
if [[ -z "${ARGUMENTS}" ]]; then
    usage
    die "ERROR: Bad number of arguments"
fi
targetDir=${1}

echo_if_not_silent "             Deduplicate backup files by Hervé Suaudeau (GPL v3)"
echo_if_not_silent "=================================================================================="
echo_if_not_silent "WARNING: This program will generate a script to do hard links between identical"
echo_if_not_silent "         files in order to save storage in archived directories."
echo_if_not_silent "         Please use only in backup dir where files will NEVER BE MODIFIED!!!"
echo_if_not_silent "=================================================================================="

#clean temp files
${RM} -rf ${DB_DIR} ${DEDUP_INSTRUCTIONS}
${MKDIR} -p ${DB_DIR}

#===========================================================================
# STEP 1: Build a database of files classified by their sizes
#===========================================================================
echo_if_not_silent "Building files list..."
CurrentNbFile=0
${FIND} "${targetDir}" -type f -size ${MIN_SIZE_OF_FILES} > "${TEMPO_LIST_OF_FILES}"
echo_if_not_silent "STEP 1: Build a database of files classified by their sizes"
TotalNbFile=$(${CAT} "${TEMPO_LIST_OF_FILES}" | ${WC} -l)
begin_time=$(now)
while IFS= read -r file; do
    #Build a database of files classified by their sizes
    ${ECHO} "${file}" >> ${DB_DIR}/$(getSizeOfFile "${file}").txt
    ((CurrentNbFile++)) || true
    if (( CurrentNbFile % 200 == 0 )); then
        #every 200 files print an advancement status
        if [[ "${SILENT}" = false ]] ; then
          elapsed_time=$(${AWK} "BEGIN {print $(now) - ${begin_time}}")
          estimated_time=$(${AWK} "BEGIN {print (${elapsed_time} * ${TotalNbFile})/(${CurrentNbFile} + 1) }")
          ${PRINTF} "\r        File #: %s/%s   Time: %s / %s        " ${CurrentNbFile} ${TotalNbFile} "$(displaytime ${elapsed_time})" "$(displaytime ${estimated_time})"
        fi
    fi
done < "${TEMPO_LIST_OF_FILES}"
if [[ "${SILENT}" = false ]] ; then
  elapsed_time=$(${AWK} "BEGIN {print $(now) - ${begin_time}}")
  ${PRINTF} "\r        File #: %s/%s    Time: %s                                                                \n" ${CurrentNbFile} ${TotalNbFile} "$(displaytime ${elapsed_time})"
  ${ECHO}
fi
#===========================================================================
# STEP 2: For each different files with the same size, build a sub-database
#         of files classified by their MD5SUM
#===========================================================================
echo_if_not_silent "STEP 2: Build a sub-database of files classified by their hash"
echo 0
((TotalNbSizes=0)) || true
#Read each db file for files with the same size
${FIND} "${DB_DIR}" -maxdepth 1 -iname "*.txt" -type f > "${TEMPO_LIST_OF_FILES}"
#TotalNbFile=$(${CAT} ${TEMPO_LIST_OF_FILES} | ${WC} -l)
begin_time=$(now)
while IFS= read -r dbfile_size; do
    #If file has more than one line
    nbLines=$(${CAT} ${dbfile_size} | ${WC} -l)
    if (( nbLines>1 )); then
        ((nbFile=0)) || true
        referenceMD5sum=""
        # For each same size file writen in this DB.
        while IFS= read -r file; do
            if (( TotalNbSizes % 20 == 0 )); then
              #every 20 files print an advancement status
              elapsed_time=$(${AWK} "BEGIN {print $(now) - ${begin_time}}")
              estimated_time=$(${AWK} "BEGIN {print (${elapsed_time} * ${TotalNbFile})/(${TotalNbSizes} + 1) }")
              if [[ "${SILENT}" = false ]] ; then
                ${PRINTF} "\r        File #: %s/%s   Time: %s / %s        " ${TotalNbSizes} ${TotalNbFile} "$(displaytime ${elapsed_time})" "$(displaytime ${estimated_time})"
              fi
            fi
            if (( nbFile == 0 )); then
                #set the first listed file as referenceFile
                referenceFile="${file}"
                referenceInode=$(getInodeOfFile "${referenceFile}")
            else
                inode=$(getInodeOfFile "${file}")
                if (( referenceInode!=inode )); then
                    #file compared to referenceFile
                    if [ "${referenceMD5sum}" == "" ]; then
                        #Md5sum referenceFile if not done before
                        referenceMD5sum="$(${MD5SUM} "${referenceFile}" | ${CUT} -f1 -d " ")"
                        #suppress potential bug of md5sum that can print a heading \ when there is special chars in filenames
                        referenceMD5sum="${referenceMD5sum/\\/}"
                        size_dir="${DB_DIR}/$(getSizeOfFile "${referenceFile}")"
                        ${MKDIR} -p "${size_dir}"
                        formated_inode=$(echoWithFixedsize 25 ${referenceInode})
                        ${ECHO} "${formated_inode}${referenceFile}" >> "${size_dir}/${referenceMD5sum}.txt"
                    fi
                    #Md5sum current file
                    fileMD5sum="$(${MD5SUM} "${file}" | ${CUT} -f1 -d " ")"
                    #suppress potential bug of md5sum that can print a heading \ when there is special chars in filenames
                    fileMD5sum="${fileMD5sum/\\/}"
                    formated_inode=$(echoWithFixedsize 25 $(getInodeOfFile "${file}"))
                    ${ECHO} "${formated_inode}${file}" >> "${size_dir}/${fileMD5sum}.txt"
                fi
            fi
            ((nbFile++)) || true
            ((TotalNbSizes++)) || true
        done < "${dbfile_size}"
    else
        ((TotalNbSizes++)) || true
    fi
done < "${TEMPO_LIST_OF_FILES}"
if [[ "${SILENT}" = false ]] ; then
  ${PRINTF} "\r        File #: %s/%s" ${TotalNbSizes} ${TotalNbFile}
  elapsed_time=$(${AWK} "BEGIN {print $(now) - ${begin_time}}")
  ${PRINTF} "\r        File #: %s/%s   Time: %s                                           \n" ${TotalNbSizes} ${TotalNbFile} "$(displaytime ${elapsed_time})"
  echo_if_not_silent
fi
#===========================================================================
# STEP 3: For each files with the same MD5SUM, make hard link between them.
#===========================================================================
echo_if_not_silent "STEP 3: Generate script"
#Add empty line in script
#${ECHO} "echo" >> ${DEDUP_INSTRUCTIONS}
((TotalSizeSaved=0)) || true
TotalSizeSaved_Pr="0,0B"
((TotalNbFileDeduplicated=0)) || true
${FIND} "${DB_DIR}" -type d > "${TEMPO_LIST_OF_DIRS}"
while read dbdir_md5sum; do
    #suppress root dir
    if [[ "${dbdir_md5sum}" != "${DB_DIR}" ]]; then
        #For all md5 files
        ${FIND} "${dbdir_md5sum}" -maxdepth 1 -iname "*.txt" -type f >"${TEMPO_LIST_OF_FILES}"
        while read md5file; do
            #Suppress lines with the same inode and then suppress inode info
            ${CAT} ${md5file} | ${SORT} | ${UNIQ} -w 25 | ${CUT} -c 26- > ${md5file}.uniq
            ((nbFile=0)) || true
            #For each files identical with different inodes
            while IFS= read -r line; do
                if (( nbFile == 0 )); then
                    referenceFile="${line}"
                    referenceInode=$(getInodeOfFile "${referenceFile}")
                else
                    inode=$(getInodeOfFile "${line}")
                    if (( referenceInode != inode )); then
                        #Generate instructions: Use printf "%q" for escaping bash characters
                        ${PRINTF} "if [[ -f \"%q\" ]]; then\n" "${referenceFile}" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "  mv \"%q\"  \"%q\"\n" "${line}" "${line}.moved" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "  cp -al \"%q\" \"%q\"\n" "${referenceFile}" "${line}" >> ${DEDUP_INSTRUCTIONS}
                        accessRight=$(${STAT} -c%a "${line}")
                        userAndGroup=$(${STAT} -c%U:%G "${line}")
                        ${PRINTF} "  chmod %q \"%q\"\n" "${accessRight}" "${line}" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "  chown %q \"%q\"\n" "${userAndGroup}" "${line}" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "  touch \"%q\" -r \"%q\"\n" "${line}" "${line}.moved" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "  rm -f \"%q\"\n" "${line}.moved" >> ${DEDUP_INSTRUCTIONS}
                        ${PRINTF} "fi\n" >> ${DEDUP_INSTRUCTIONS}
                        currentSize=$(getSizeOfFile "${referenceFile}")
                        ((TotalSizeSaved=TotalSizeSaved + currentSize)) || true
                        TotalSizeSaved_Pr=$(${NUMFMT} --to=iec-i --suffix=B --format="%.1f" ${TotalSizeSaved})
                        ((TotalNbFileDeduplicated++)) || true
                        if (( TotalNbFileDeduplicated % 20 == 0 )); then
                          if [[ "${SILENT}" = false ]] ; then
                            ${PRINTF} "\r        Files deduplicated : %s     Total saved size : %s" ${TotalNbFileDeduplicated} ${TotalSizeSaved_Pr}
                            ${PRINTF} "printf \"\\\r        Files deduplicated : %s     Total saved size : %s\"\n" ${TotalNbFileDeduplicated} ${TotalSizeSaved_Pr} >> ${DEDUP_INSTRUCTIONS}
                          fi
                        else
                          ${ECHO} >> ${DEDUP_INSTRUCTIONS}
                        fi
                        ${ECHO} >> ${DEDUP_INSTRUCTIONS}
                    fi
                fi
                ((nbFile++)) || true
            done < "${md5file}.uniq"
        done < "${TEMPO_LIST_OF_FILES}"
    fi
done < "${TEMPO_LIST_OF_DIRS}"
if [[ "${SILENT}" = false ]] ; then
  ${PRINTF} "\r        File # %s     Total saved size : %s           \n" ${TotalNbFileDeduplicated} ${TotalSizeSaved_Pr}
  if (( TotalSizeSaved>0 )); then
    ${PRINTF} "printf \"\\\r        Files deduplicated : %s     Total saved size : %s \\\n \"\n" ${TotalNbFileDeduplicated} ${TotalSizeSaved_Pr} >> ${DEDUP_INSTRUCTIONS}
  fi
fi

#===========================================================================
# STEP 4: Display instructions
#===========================================================================
${RM} -rf ${DB_DIR} ${TEMPO_LIST_OF_DIRS} ${TEMPO_LIST_OF_FILES}
echo_if_not_silent "----------------------------------------------------------------------------------"
if [[ "${SILENT}" = false ]] ; then
  ${PRINTF} "You can launch deduplicate instructions with following command for saving %s\n" $(${NUMFMT} --to=iec-i --suffix=B --format="%.1f" ${TotalSizeSaved})
fi
if [[ -e ${DEDUP_INSTRUCTIONS} ]]; then
  if [[ "${SILENT}" = false ]] ; then
    ${ECHO} . ${DEDUP_INSTRUCTIONS}
  else
    #Silent mode=>Lauch the script
    . ${DEDUP_INSTRUCTIONS}
  fi
else
  echo_if_not_silent "No file. Nothing to deduplicate."
fi
