#!/bin/bash

#----------------------------------------------------------------------
#  Preliminary actions
#----------------------------------------------------------------------
readonly WHICH=/usr/bin/which

die() { echo "$@" 1>&2 ; exit 1; }

#===  FUNCTION  ================================================================
#         NAME:  getPathAndCheckInstall
#  DESCRIPTION:  Get the path of an application and check if it is installed.
#        USAGE:  $MYAPP_PATH=$(getPathAndCheckInstall myapp)
# PARAMETER  1:  myapp : application
# RETURN VALUE:  Absolute path of application
#===============================================================================
getPathAndCheckInstall() {
    #argument cannot be empty ==> die
    if [[ -z "${1}" ]]; then
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
readonly CAT=$(getPathAndCheckInstall cat)
readonly CUT=$(getPathAndCheckInstall cut)
readonly ECHO=$(getPathAndCheckInstall echo)
readonly MKDIR=$(getPathAndCheckInstall mkdir)
readonly RM=$(getPathAndCheckInstall rm)
readonly MKTEMP=$(getPathAndCheckInstall mktemp)

readonly STAT=$(getPathAndCheckInstall stat)
readonly FIND=$(getPathAndCheckInstall find)
readonly MD5SUM=$(getPathAndCheckInstall md5sum)
readonly UNIQ=$(getPathAndCheckInstall uniq)
readonly WC=$(getPathAndCheckInstall wc)
readonly SORT=$(getPathAndCheckInstall sort)
readonly PRINTF=$(getPathAndCheckInstall printf)
readonly NUMFMT=$(getPathAndCheckInstall numfmt)

readonly DB_DIR=$(${MKTEMP} -d --suffix=".dedup")
readonly DEDUP_INSTRUCTIONS=$(${MKTEMP} --suffix=".deduplicate_instructions.sh")
readonly TEMPO_LIST_OF_FILES=$(${MKTEMP} --suffix=".deduptempfiles.txt")
readonly TEMPO_LIST_OF_DIRS=$(${MKTEMP} --suffix=".deduptempdirs.txt")

#Simple functions:
#-----------------
getInodeOfFile() {
    ${ECHO} $(${STAT} -c "%i" -- "${1}")
}
getSizeOfFile() {
    ${ECHO} $(${STAT} -c "%s" -- "${1}")
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
#         NAME:  areFilesHardlinked
#  DESCRIPTION:  Test if two files are hard linked
#        USAGE:  areFilesHardlinked "File1" "File2"
#      EXAMPLE:  if areFilesHardlinked "File1" "File2" ; then
#                   Action si OK
#                fi
# PARAMETER  1:  File1 : Fichier 1
# PARAMETER  2:  File2 : Fichier 2
#===============================================================================
areFilesHardlinked() {
    #arguments cannot be empty ==> die
    if [[ -z "${2}" || -z "${1}" ]]; then
        die "FATAL ERROR: Bad number of arguments in function areHardlinked"
    fi

    #Are both true files?
    if [[ -f "${1}" && -f  "${2}" ]] ; then
        local inode_file1=$(getInodeOfFile "${1}")
        local inode_file2=$(getInodeOfFile "${2}")
        #Inodes are the same?
        if [[ ${inode_file1} == ${inode_file2} ]] ; then            \
            return 0
        fi
    fi
    return 1
}

#===========================================================================
# STEP 0: Display warning and get parameters
#===========================================================================
${ECHO} "==========================================================================="
${ECHO} "WARNING: This program will generate a script to  hard links between files "
${ECHO} "         that are identical in order to save storage in archived directories."
${ECHO} "         1) Please use only in backup dir where files will NEVER BE MODIFIED!!!"
${ECHO} "         2) This script may also loose rights and owners of deduplicated files."
${ECHO} "==========================================================================="

#arguments cannot be empty ==> die
if [[ -z "${1}" ]]; then
    die "FATAL ERROR: Bad number of arguments in main"
fi
targetDir=${1}

#clean temp files
${RM} -rf ${DB_DIR} ${DEDUP_INSTRUCTIONS}
${MKDIR} -p ${DB_DIR}

#===========================================================================
# STEP 1: Build a database of files classified by their sizes
#===========================================================================
${ECHO} "STEP 1: Build a database of files classified by their sizes"
#for every file su
CurrentNbFile=0
${FIND} "${targetDir}" -type f -size +0 > "${TEMPO_LIST_OF_FILES}"
TotalNbFile=$(${CAT} ${TEMPO_LIST_OF_FILES} | ${WC} -l)
while IFS= read -r file; do
    #Build a database of files classified by their sizes
    ${ECHO} "${file}" >> ${DB_DIR}/$(getSizeOfFile "${file}").txt
    ((CurrentNbFile++))
    ${PRINTF} "\r        File #: %s/%s" ${CurrentNbFile} ${TotalNbFile}
done < "${TEMPO_LIST_OF_FILES}"
${ECHO}
#===========================================================================
# STEP 2: For each different files with the same size, build a sub-database
#         of files classified by their MD5SUM
#===========================================================================
${ECHO} "STEP 2: Build a sub-database of files classified by their hash"
((TotalNbSizes=0))
#Read each db file for files with the same size
${FIND} "${DB_DIR}" -type f > "${TEMPO_LIST_OF_FILES}"
TotalNbFile=$(${CAT} ${TEMPO_LIST_OF_FILES} | ${WC} -l)
while IFS= read -r dbfile_size; do
    #If file has more than one line
    nbLines=$(${CAT} ${dbfile_size} | ${WC} -l)
    if (( nbLines>1 )); then
        ((nbFile=0))
        referenceMD5sum=""
        # For each same size file writen in this DB.
        while IFS= read -r file; do
            if (( nbFile == 0 )); then
                #set the first listed file as referenceFile
                referenceFile=${file}
            else
                #file compared to referenceFile
                if !(areFilesHardlinked "${referenceFile}" "${file}") ; then
                    if [ "${referenceMD5sum}" == "" ]; then
                        #Md5sum referenceFile if not done before
                        referenceMD5sum=$(${MD5SUM} "${referenceFile}" | ${CUT} -f1 -d " ")
                        size_dir=${DB_DIR}/$(getSizeOfFile "${referenceFile}")
                        ${MKDIR} -p ${size_dir}
                        formated_inode=$(echoWithFixedsize 25 $(getInodeOfFile "${referenceFile}"))
                        ${ECHO} "${formated_inode}${referenceFile}" >> ${size_dir}/${referenceMD5sum}.txt
                    fi
                    #Md5sum current file
                    fileMD5sum=$(${MD5SUM} "${file}" | ${CUT} -f1 -d " ")
                    formated_inode=$(echoWithFixedsize 25 $(getInodeOfFile "${file}"))
                    ${ECHO} "${formated_inode}${file}" >> ${size_dir}/${fileMD5sum}.txt
                fi
            fi
            ((nbFile++))
        done < "${dbfile_size}"
        ${PRINTF} "\r        Number different files : %s/%s" ${TotalNbSizes} ${TotalNbFile}
    fi
    ((TotalNbSizes++))
done < "${TEMPO_LIST_OF_FILES}"
${ECHO}
#===========================================================================
# STEP 3: For each files with the same MD5SUM, make hard link between them.
#===========================================================================
${ECHO} "STEP 3: Generate script"
((TotalSizeSaved=0))
${FIND} "${DB_DIR}" -type d > "${TEMPO_LIST_OF_DIRS}"
while read dbdir_md5sum; do
    #suppress root dir
    if [[ "${dbdir_md5sum}" != "${DB_DIR}" ]]; then
        #For all md5 files
        ${FIND} "${dbdir_md5sum}" -type f > "${TEMPO_LIST_OF_FILES}"
        while read md5file; do
            #Suppress lines with the same inode and then suppress inode info
            ${CAT} ${md5file} | ${SORT} | ${UNIQ} -w 25 | ${CUT} -c 26- > ${md5file}.uniq
            ((nbFile=0))
            #For each files identical with different inodes
            while IFS= read -r line; do
                if (( nbFile == 0 )); then
                    referenceFile="${line}"
                else
                    #Generate instructions
                    ${ECHO} rm -f \"${line}\" >> ${DEDUP_INSTRUCTIONS}
                    ${ECHO} cp -al \"${referenceFile}\" \"${line}\" >> ${DEDUP_INSTRUCTIONS}
                    currentSize=$(getSizeOfFile "${referenceFile}")
                    ((TotalSizeSaved=TotalSizeSaved + currentSize))
                    ${PRINTF} "\r        Total saved size : %s" $(${NUMFMT} --to=iec-i --suffix=B --format="%.1f" ${TotalSizeSaved})
                fi
                ((nbFile++))
            done < "${md5file}.uniq"
        done < "${TEMPO_LIST_OF_FILES}"
    fi
done < "${TEMPO_LIST_OF_DIRS}"

${ECHO}
#===========================================================================
# STEP 4: Display instructions
#===========================================================================
${ECHO}
#${ECHO} "Here are the instructions for deduplicate:"
#${ECHO} "----------------------------------------------------------"
#cat ${DEDUP_INSTRUCTIONS}
${RM} -rf ${DB_DIR} ${TEMPO_LIST_OF_DIRS} ${TEMPO_LIST_OF_FILES}
${ECHO} "----------------------------------------------------------"
${PRINTF} "You can launch deduplicate instructions with following command for saving %s\n" $(${NUMFMT} --to=iec-i --suffix=B --format="%.1f" ${TotalSizeSaved})
${ECHO} . ${DEDUP_INSTRUCTIONS}
