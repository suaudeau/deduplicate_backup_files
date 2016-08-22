deduplicate backup files
========================

###Description:
Save space in backups : Convert redondent files to hard links

WARNING: This program will generate a script to  hard links between files that are identical in order to save storage in archived directories.
1) Please use only in backup dir where files will NEVER BE MODIFIED!!!
2) This script may also loose rights and owners of deduplicated files.

###Configuration:
none

###Options:  
none

###Requirement:  
none

###Bugs:

###Notes:  

###Author:  
Hervé SUAUDEAU, herve.suaudeau (arob.) parisdescartes.fr (CNRS)

###Revisions:
| Version |    Date    | Comments                                              |
| ------- | ---------- | ----------------------------------------------------- |
| 1.0     | 22.08.2016 | First commit into Github. Production version Ubsed|

###Licence
    GPL v3
