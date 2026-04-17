# Copyright © 2026 Function Refined LLC
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without
# restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom
# the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE
# AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#!/bin/env sh

g_password=""
g_original_path=""
g_file_max_size=50
g_file_length=512
g_file_list=""

#	generate a hash based on the directory
#  make a list of files that match
#  go through, and as a hash is generated, check for if it exists in the list
#  if it does, delete it from the list
#  at the end, remove all files left in the list
#
# tar, xz, and encrypt
# tar -cvJ a/ | openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000000 -e -pass pass:a123 > test_$(d).bgb
#
# decrypt and decompress
# openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000000 -e -pass pass:a123 -d -in test_2025_12_08.bgb | tar -xvJ

err_usage() {
	[ -n "$1" ] && echo "$1"
	echo "Usage: $0 -s <dir to backup> -d <destination dir> -p <password> -m <megabytes to separate - default 50> -l <archive max character length - default 512>"
	exit 1
}

err_exit() {
	echo ""
	date
	echo "error: $1"
	echo ""
	echo "--------------------"
	echo "backup FAILED!"
	echo ""
	exit 1
}

# $1 dir
# $2 maxsize
check_size() {
	_cs_check=$(du "$1" -b | tail -n 1 | awk \{'print $1'\})
	[ "$_cs_check" -ge "$2" ] && return 0
	return 1
}

# $1 folder name
# $2 checksum
filename_create() {
	_c_tmp=$(echo "$1$2" | cut -c1-"$g_file_length")
	echo "$g_original_path/$_c_tmp.bgb"
}

# Check if the archive exists. If not, then create it
# $1 path
# $2 1 recursive, 0 otherwise
# $3 folder name
file_check_and_create() {
	_fc_tmp_path="$1"
	if [ "$2" -eq 1 ]; then
		# recursive
		_fc_q=$(sha256_dir "$1" 1)
		_fc_filename=$(filename_create "$3" "$_fc_q")
		list_item_exists "$_fc_filename"
		[ $? -eq 0 ] && file_create_recursive "$_fc_filename" "$_fc_tmp_path"
	else # non-recursive
		_fc_q=$(sha256_dir "$1" 0)
		_fc_filename=$(filename_create "$3" "$_fc_q")
		list_item_exists "$_fc_filename"
		[ $? -eq 0 ] && file_create_from_current_dir "$_fc_filename" "$_fc_tmp_path"
	fi
	list_item_remove "$_fc_filename"
}

# $1 filename
# $2 dir to compress
file_create_from_current_dir() {
	echo "Creating tar non-recursively from $2, filename: $1"
	find "$2" -maxdepth 1 -mindepth 1 -type f -print0 | tar -cJ --null -T - | openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000000 -e -pass pass:"$g_password" > "$1"
	[ $? -eq 0 ] || err_exit "Could not create tar from non-recursive command for directory $2"
	return 0
}

# $1 filename
# $2 directory
file_create_recursive() {
	echo "Creating tar recursively from $2, filename: $1"
	tar -cJ "$2"/ | openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000000 -e -pass pass:"$g_password" > "$1"
	[ $? -eq 0 ] || err_exit "Could not create tar from recursive command for directory $2"
	return 0
}

# $1 dir to navigate to
# $2 max size
# $3 name (dir_)
nav_dirs() {
	check_size "$1" "$2"
	if [ $? -eq 1 ]; then
		file_check_and_create "$1" 1 "$3"
	else
		file_check_and_create "$1" 0 "$3"
		for _nd_dir in $(find "$1" -maxdepth 1 -type d | tail -n+2 | sed "s/^.*\///g" | sort)
		do
			#echo "dir: $1/$_nd_dir"
			nav_dirs "$1/$_nd_dir" "$2" "$3"
		done
	fi
}

list_item_exists() {
	for _le_item in $g_file_list
	do
		_le_q=$(echo "$_le_item" | grep "$1")
		[ -n "$_le_q" ] && return 1
	done
	return 0
}

list_item_print() {
	_lp_i=0
	for _lp_item in $g_file_list
	do
		echo "item $_lp_i: $_lp_item"
		_lp_i=$((_lp_i+1))
	done
}

list_item_remove() {
	g_file_list=$(echo "$g_file_list" | sed "s|$1||g")
}

list_item_rm_all_files() {
	for _lr_item in $g_file_list
	do
		echo "--------> rm file: $_lr_item"
		rm -f "$_lr_item"
		[ $# -ne 0 ] && err_exit "Could not remove file: $_lr_item"
	done
}

#$1 string
#$2 char
# echo position
# return 1 if found, otherwise 0
find_char_pos_in_string() {
	_fs_split=$(echo "$1" | sed -E 's/(.)/\1\n/g')
	_fs_i=${#1}
	for _fs_c in $_fs_split
	do
		if [ "$_fs_c" = "$2" ]; then
			echo "$_fs_i"
			return 1
		fi
		_fs_i=$((_fs_i-1))
	done
	return 0
}

# Change to the correct path
cd_to_working_path() {
	cd "$1"
	[ $? -eq 0 ] || err_exit "Could not change directory"
	return 0
}

list_item_create_list() {
	g_file_list=$(ls "$1"*.bgb 2>/dev/null | sort)
}

# $1 path
# returns path sepearated string with the two parts, separated by newline
# eg /rd/path_to_backup will split /rd/ and path_to_backup
split_path_in_two() {
	_st_tmp=$(echo "$1" | rev)
	_st_q=$(find_char_pos_in_string "$_st_tmp" "/")
	[ $? -eq 0 ] && return 1
	if [ "$_st_q" -eq 1 ]; then
		_st_second_part="$1"
	else
		_st_len=${#1}
		_st_q=$((_st_q-1))
		_st_first_part=$(echo "$1" | cut -c1-"$_st_q")

		_st_q=$((_st_q+2))
		_st_second_part=$(echo "$1" | cut -c"$_st_q"-"$_st_len")
	fi
	echo "$_st_first_part"
	echo "$_st_second_part"
	return 0
}

# $1 string
# $2 position
# return line at specified position
string_get_line() {
	_sl_i=0
	for _sl_item in $1
	do
		if [ $_sl_i -eq "$2" ]; then
			echo "$_sl_item"
			return 0
		fi
		_sl_i=$((_sl_i+1))
	done
	return 1
}

# $1 dir
# $2 1 recursive, 0 non-recursive
sha256_dir() {
	if [ "$2" -eq 0 ]; then
		_sd_q=$(find "$1" -maxdepth 1 -type f -exec sha256sum {} \;  | sort -k2 | cut -d ' ' -f1 | xargs | sha256sum | cut -d ' ' -f1)
	else
		_sd_q=$(find "$1" -type f -exec sha256sum {} \;  | sort -k2 | cut -d ' ' -f1 | xargs | sha256sum | cut -d ' ' -f1)
	fi
	# Add the sha256 of the directory to the files found
	# helps with directories containing no files
	_sd_q=$(echo "$_sd_q $1" | sha256sum | cut -d ' ' -f1)
	echo "$_sd_q"
}

# Create extract script for the archive
# $1 first part of archive name before the checksum
restore_script_create() {
	_rc_f="$g_original_path/$1extract.sh"
	# If the file exists, do not create it
	[ ! -f "$_rc_f" ] || return 0
	echo "#!/bin/env sh" > $_rc_f
	[ $? -eq 0 ] || return 1
	echo "" >> $_rc_f
	echo "# unencrypt and extract" >> $_rc_f
	echo "" >> $_rc_f
	echo "# example:" >> $_rc_f
	echo "# for z in *.bgb; do ./$1extract.sh \"\$z\" \$(cat ~/.config/p.txt); done" >> $_rc_f
	echo "" >> $_rc_f
	echo "" >> $_rc_f
	echo "# main" >> $_rc_f
	echo "" >> $_rc_f
	echo "[ \$# -ne 2 ] && echo \"Usage: \$0 <file to restore> <password>\" && exit 1" >> $_rc_f
	echo "" >> $_rc_f
	echo "echo \"Extracting \$1\"" >> $_rc_f
	echo "openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 1000000 -e -pass pass:\"\$2\" -d -in \"\$1\" | tar -xJ" >> $_rc_f
	chmod 755 $_rc_f
	[ $? -eq 0 ] || return 1
	return 0
}


# main

[ $# -lt 2 ] || [ $# -gt 8 ] && err_usage

tmp=""
g_original_path="$PWD"

while getopts ":d:s:p:m:l:" option; do
	case $option in
		d)
			g_original_path="$OPTARG"
			;;
		s)
			tmp=$(echo "$OPTARG" | sed "s/\/$//g")
			;;
		p)
			g_password="$OPTARG"
			;;
		m)
			g_file_max_size="$OPTARG"
			;;
		l)
			g_file_length="$OPTARG"
			;;
		*)
			;;
	esac
done

[ -z "$tmp" ] && err_usage "A directory to backup must be specified"
[ -z "$g_password" ] && err_usage "A password must be specified"

g_file_max_size=$((g_file_max_size*1048576))

file_part1=""
file_part2=""
g_file_length=$((g_file_length-4))

q=$(split_path_in_two "$tmp")
file_part1=$(string_get_line "$q" 0)
file_part2=$(string_get_line "$q" 1)

# if there is a first part of the directory specified, cd to it
if [ -n "$file_part1" ]; then
	cd_to_working_path "$file_part1"
else
	file_part1="."
	file_part2="$tmp"
fi

[ -z "$file_part2" ] && err_exit "A subdirectory must be specified"
[ ! -d "$file_part2" ] && err_exit "The specified subdirectory does not exist"

file_part1="$file_part2"
file_part2=$(echo "$file_part2" | sed "s/$/_/g")

list_item_create_list "$g_original_path/$file_part2"

l=$((g_file_length-${#file_part1}-3))
[ "$l" -lt 0 ] && err_exit "The directory name is longer than the allowed filename length!\nTake into account that 4 characters are used for the extension and extra part"

s=$((g_file_max_size/1048576))
l=$((g_file_length+4))
echo "Archiving directory $file_part1 with max size of $s megabytes and max file length $l characters"

restore_script_create "$file_part2"
[ $? -eq 0 ] || err_exit "Error creating restore script!"

OIFS="$IFS"
IFS='
'
nav_dirs "$file_part1" $g_file_max_size "$file_part2"
IFS="$OIFS"

# remove anything still in the list with the first part of the filename
list_item_rm_all_files
exit 0
