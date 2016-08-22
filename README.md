deduplicate backup files
========================

###Description:
Save space in backups : Convert redondent files to hard links

WARNINGS: This script will generate a scipt to  hard links between files that are identical in order to save storage in archived directories.
- Please use only in backup dir where files are NEVER MODIFIED!!!
- This script may also loose rights and owners of deduplicated files.

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
