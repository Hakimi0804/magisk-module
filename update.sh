#!/bin/bash
# shellcheck disable=SC2129

# pretty print function
function print_info() {
  echo -e "\e[1;32m[*]\e[0m $1"
}

# pretty error print function
function print_error() {
  echo -e "\e[1;31m[*]\e[0m $1"
}

# function to handle cd error function -> exit
function handle_cd_error() {
  # check if return code is 1
  if [ $? -eq 5 ]; then
    print_error "Could not enter directory: $1"
    exit 1
  fi
}

##########################################################
##########################################################

# query list of folders in the current directory
folders=$(ls -d */ | sed 's/\///g')
ignore_folders=$(sed 's/#.*//g' .gitignore | sed 's/\///g')

enable_compression=true

##########################################################
##########################################################

print_info "Note: all output will be redirected to update.log"

# Decompress log file if compressed (lz4)
if [ -f update.log.lz4 ]; then
  print_info "Decompressing log file"
  lz4 --rm -qd update.log.lz4
fi

for folder in $folders; do

  # skip folders in .gitignore
  if [[ $ignore_folders =~ $folder ]]; then
    continue
  fi

  print_info "----------------------------------------------------"

  # run git pull in each folder
  print_info "Updating $folder"
  (
    cd "$folder" || exit 5
    git clean -df
    git stash
    git pull
  ) &>> update.log
  handle_cd_error "$folder"

  # enter every folder and zip the content recursively
  print_info "Zipping $folder"
  (
    cd "$folder" || exit 5
    zip -r "$folder.zip" *
  ) &>> update.log
  handle_cd_error "$folder"

  # copy generated zip to ~/shared/modules
  # make sure the folder exist first
  print_info "Copying $folder.zip to ~/shared/modules" # (this folder will be synced to my phone by syncthing/KDE Connect)
  (
    mkdir -p ~/shared/modules
    cp "$folder/$folder.zip" ~/shared/modules
  ) &>> update.log

done

if [[ $enable_compression == true ]]; then
  print_info "----------------------------------------------------"
  print_info "Compressing log file"
  lz4 --rm -qd update.log
fi
