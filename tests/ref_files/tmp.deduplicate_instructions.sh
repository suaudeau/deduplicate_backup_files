if [[ -f "./file10k_double.txt" ]]; then
  mv "./dup1/file10k_double.txt"  "./dup1/file10k_double.txt.moved"
  cp -al "./file10k_double.txt" "./dup1/file10k_double.txt"
  chmod 712 "./dup1/file10k_double.txt"
  chown USER:USER "./dup1/file10k_double.txt"
  touch "./dup1/file10k_double.txt" -r "./dup1/file10k_double.txt.moved"
  rm -f "./dup1/file10k_double.txt.moved"
fi


if [[ -f "./file1k_double.txt" ]]; then
  mv "./dup1/file1k_double.txt"  "./dup1/file1k_double.txt.moved"
  cp -al "./file1k_double.txt" "./dup1/file1k_double.txt"
  chmod 712 "./dup1/file1k_double.txt"
  chown USER:USER "./dup1/file1k_double.txt"
  touch "./dup1/file1k_double.txt" -r "./dup1/file1k_double.txt.moved"
  rm -f "./dup1/file1k_double.txt.moved"
fi


if [[ -f "./file100k_triple.txt" ]]; then
  mv "./dup1/file100k_triple.txt"  "./dup1/file100k_triple.txt.moved"
  cp -al "./file100k_triple.txt" "./dup1/file100k_triple.txt"
  chmod 712 "./dup1/file100k_triple.txt"
  chown USER:USER "./dup1/file100k_triple.txt"
  touch "./dup1/file100k_triple.txt" -r "./dup1/file100k_triple.txt.moved"
  rm -f "./dup1/file100k_triple.txt.moved"
fi


if [[ -f "./file100k_triple.txt" ]]; then
  mv "./dup1/dup2/file100k_triple.txt"  "./dup1/dup2/file100k_triple.txt.moved"
  cp -al "./file100k_triple.txt" "./dup1/dup2/file100k_triple.txt"
  chmod 713 "./dup1/dup2/file100k_triple.txt"
  chown USER:adm "./dup1/dup2/file100k_triple.txt"
  touch "./dup1/dup2/file100k_triple.txt" -r "./dup1/dup2/file100k_triple.txt.moved"
  rm -f "./dup1/dup2/file100k_triple.txt.moved"
fi


printf "\r        Files deduplicated : 4     Total saved size : 206,1KiB \n "
