if [[ -f "./file10k_double.txt" ]]; then
  rm -f "./dup1/file10k_double.txt"
  cp -al "./file10k_double.txt" "./dup1/file10k_double.txt"
  chmod 712 "./dup1/file10k_double.txt"
  chown USER:USER "./dup1/file10k_double.txt"
fi


if [[ -f "./file1k_double.txt" ]]; then
  rm -f "./dup1/file1k_double.txt"
  cp -al "./file1k_double.txt" "./dup1/file1k_double.txt"
  chmod 712 "./dup1/file1k_double.txt"
  chown USER:USER "./dup1/file1k_double.txt"
fi


if [[ -f "./file100k_triple.txt" ]]; then
  rm -f "./dup1/file100k_triple.txt"
  cp -al "./file100k_triple.txt" "./dup1/file100k_triple.txt"
  chmod 712 "./dup1/file100k_triple.txt"
  chown USER:USER "./dup1/file100k_triple.txt"
fi


if [[ -f "./file100k_triple.txt" ]]; then
  rm -f "./dup1/dup2/file100k_triple.txt"
  cp -al "./file100k_triple.txt" "./dup1/dup2/file100k_triple.txt"
  chmod 713 "./dup1/dup2/file100k_triple.txt"
  chown USER:adm "./dup1/dup2/file100k_triple.txt"
fi


printf "\r        Files deduplicated : 4     Total saved size : 206,1KiB \n "
