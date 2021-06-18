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
  chmod 712 ${TARGET_DIR}/dup1/*.txt
  chown $USER:$USER ${TARGET_DIR}/dup1/*.txt
  cp -a ${TARGET_DIR}/*.txt ${TARGET_DIR}/dup1/dup2
  chmod 713 ${TARGET_DIR}/dup1/dup2/*.txt
  chown $USER:adm ${TARGET_DIR}/dup1/dup2/*.txt
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
   [ "${lines[4]}"  = "         Please use only in backup dir where files will NEVER BE MODIFIED!!!" ]
   [ "${lines[5]}"  = "==================================================================================" ]
   [ "${lines[6]}"  = "Building files list..." ]
   [ "${lines[7]}"  = "STEP 1: Build a database of files classified by their sizes" ]
   [ "${lines[9]}"  = "STEP 2: Build a sub-database of files classified by their hash" ]
   [ "${lines[12]}"  = "STEP 3: Generate script" ]
   [ "${lines[14]}"  = "----------------------------------------------------------------------------------" ]
   [ "${lines[15]}"  = "You can launch deduplicate instructions with following command for saving 206,1KiB" ]
   [[ "${lines[16]#*]:}" =~ ^\.\ /tmp/tmp\..*\.deduplicate_instructions\.sh$ ]]
   [ "${#lines[@]}"  = "17" ]
   GENERATED_FILE=$(echo "${lines[16]#*]:}" | cut -d ' ' -f 2)
   cat ${GENERATED_FILE} | sed "s/${TARGET_DIR//\//\\\/}/\./g" | sed "s/ chown $USER:$USER/ chown USER:USER/g" | sed "s/ chown $USER:adm/ chown USER:adm/g" > ${GENERATED_FILE}.cleaned

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