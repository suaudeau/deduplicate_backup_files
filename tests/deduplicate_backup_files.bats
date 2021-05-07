# Script bats-code (syntaxe bash)

# Fonction lancée AVANT chaque test unitaire
setup() {
  readonly TARGET_DIR=$(mktemp -d) #création d'un dossier de destination temporaire
  base64 /dev/urandom | head -c 100000 > ${TARGET_DIR}/file100k_triple.txt
  base64 /dev/urandom | head -c 100000 > ${TARGET_DIR}/file100k_uniq.txt
  base64 /dev/urandom | head -c 10000 > ${TARGET_DIR}/file10k_double.txt
  base64 /dev/urandom | head -c 1000 > ${TARGET_DIR}/file1k_double.txt
  mkdir  ${TARGET_DIR}/dup1
  mkdir  ${TARGET_DIR}/dup1/dup2
  cp -a ${TARGET_DIR}/*.txt ${TARGET_DIR}/dup1
  cp -a ${TARGET_DIR}/*.txt ${TARGET_DIR}/dup1/dup2
  rm ${TARGET_DIR}/dup1/file100k_uniq.txt ${TARGET_DIR}/dup1/dup2/file100k_uniq.txt ${TARGET_DIR}/dup1/dup2/file10k_double.txt ${TARGET_DIR}/dup1/dup2/file1k_double.txt
}

# Fonction lancée APRÈS chaque test unitaire
teardown() {
  rm -rf "${TARGET_DIR}" #Effacer le dossier de destination temporaire
}

# Pour debug : pour imprimer la sortie au format de test
printlines() {
  num=0
  for line in "${lines[@]}"; do
    echo "[ \"\${lines[$num]}\"  = \"${line}\" ]"
    num=$((num + 1))
  done
}

@test "deduplicate_backup_files : arguments par défaut" {
  [ "444K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]

  run ../deduplicate_backup_files.sh "$TARGET_DIR"

  # Pas d'erreur de retour : la valeur de "exit" est 0
  [ "${status}" -eq 0 ]
  [ "444K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
    printlines 
   [ "${lines[0]}"  = "             Deduplicate backup files by Hervé Suaudeau (GPL v3)" ]
   [ "${lines[1]}"  = "==================================================================================" ]
   [ "${lines[2]}"  = "WARNING: This program will generate a script to do hard links between identical" ]
   [ "${lines[3]}"  = "         files in order to save storage in archived directories." ]
   [ "${lines[4]}"  = "         1) Please use only in backup dir where files will NEVER BE MODIFIED!!!" ]
   [ "${lines[5]}"  = "         2) This script may also loose rights and owners of deduplicated files." ]
   [ "${lines[6]}"  = "==================================================================================" ]
   [ "${lines[7]}"  = "Building files list..." ]
   [ "${lines[8]}"  = "STEP 1: Build a database of files classified by their sizes" ]
   [ "${lines[10]}"  = "STEP 2: Build a sub-database of files classified by their hash" ]
   [ "${lines[13]}"  = "STEP 3: Generate script" ]
   [ "${lines[15]}"  = "----------------------------------------------------------------------------------" ]
   [ "${lines[16]}"  = "You can launch deduplicate instructions with following command for saving 206,1KiB" ]
   [[ "${lines[17]#*]:}" =~ ^\.\ /tmp/tmp\..*\.deduplicate_instructions\.sh$ ]]
   [ "${#lines[@]}"  = "18" ]
   GENERATED_FILE=$(echo "${lines[17]#*]:}" | cut -d ' ' -f 2)
   cat ${GENERATED_FILE} | sed "s/${TARGET_DIR//\//\\\/}/\./g" > ${GENERATED_FILE}.cleaned
   [ "" = "$(diff ${GENERATED_FILE}.cleaned ref_files/tmp.deduplicate_instructions.sh)" ]
}


@test "deduplicate_backup_files : mode silent" {
  [ "444K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #inodes are differents
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]

  run ../deduplicate_backup_files.sh --silent "$TARGET_DIR"

  # Pas d'erreur de retour : la valeur de "exit" est 0
  [ "${status}" -eq 0 ]
  #Le dossier ne pèse plus que 228K
  [ "228K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #same inode
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file10k_double.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file10k_double.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file1k_double.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file1k_double.txt)" ]
}

@test "deduplicate_backup_files : more than 10K" {
  [ "444K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #inodes are differents
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]

  run ../deduplicate_backup_files.sh --silent --fast "$TARGET_DIR"

  # Pas d'erreur de retour : la valeur de "exit" est 0
  [ "${status}" -eq 0 ]
  #Le dossier ne pèse plus que 228K
  [ "244K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #same inode
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file10k_double.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file10k_double.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file1k_double.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file1k_double.txt)" ]
}

@test "deduplicate_backup_files : more than 5K" {
  [ "444K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #inodes are differents
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]

  run ../deduplicate_backup_files.sh --silent --min_size 5120 "$TARGET_DIR"

  du -sh $TARGET_DIR
  # Pas d'erreur de retour : la valeur de "exit" est 0
  [ "${status}" -eq 0 ]
  #Le dossier ne pèse plus que 228K
  [ "232K	$TARGET_DIR" = "$(du -sh $TARGET_DIR)" ]
  #same inode
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file100k_triple.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/dup2/file100k_triple.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file10k_double.txt)" = "$(stat --format='%i' $TARGET_DIR/dup1/file10k_double.txt)" ]
  [ "$(stat --format='%i' $TARGET_DIR/file1k_double.txt)" != "$(stat --format='%i' $TARGET_DIR/dup1/file1k_double.txt)" ]
}