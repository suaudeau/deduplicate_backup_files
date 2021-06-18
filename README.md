Deduplicate backup files
========================

### Description:
Save space in backups : Convert redondent files to hard links

**WARNING**: This program will generate a script to  hard links between files that are identical in order to save storage in archived directories.
 1. Please use only in backup dir where files will NEVER BE MODIFIED!!!
 2. This script may also loose rights and owners of deduplicated files.

### Configuration:
none

### Options:
| Syntax                             | Meaning|
| ---------------------------------- | ----------------------------------------------------- |
| **-s**, **--silent**, **--daemon** | Do not print anything and lauch deduplicate script after analysis.|
| **-f**, **--fast**                 | Do a fast analysis (ignore files equal or less than 10k)|
| **-m** *NUM*, **--min_size** *NUM* | Ignore files equal or less than *NUM* bytes.|

### Examples:
     deduplicate_backup_files.sh dir/subdir/backup_to_deduplicate
     deduplicate_backup_files.sh --min_size 1024 dir/subdir/backup_to_deduplicate_bigger_files
     deduplicate_backup_files.sh --silent dir/subdir/backup_to_deduplicate_automatically

### Requirement:  
none

### Bugs:

### Notes:  

### Author:  
Hervé SUAUDEAU, herve.suaudeau (arob.) parisdescartes.fr (CNRS)

### Revisions:
| Version |    Date    | Comments                                              |
| ------- | ---------- | ----------------------------------------------------- |
| 1.0     | 22.08.2016 | First commit into Github. Production version used|
| 1.1     | 24.08.2016 | Correct sparses bugs that can occurs sometimes ("readonly" attribute can misleading content of variables, "exit 1" can exit the shell)|
| 1.2     | 25.08.2016 | Optimize speed|
| 1.3     | 29.08.2016 | Correct bug that do not optimize files with multple hard links AND copies|
| 1.4     | 30.08.2016 | Script can manage special char in filenames like "'$\%^{} ...|
| 1.5     |  5.09.2016 | Add time tracking and check that file replacement exist before rm |
| 1.6     | 16.09.2016 | Add options -s, -f, -m |
| 1.7     | 07.05.2021 | Compatibility with Python 3 and add unit tests (bats tool) |
| 1.8     | 18.06.2021 | Preserve dates, ownership and rights of deduplicated files |


### Licence
    GPL v3
