# hash_backup
Encrypted backup which splits archives up into a certain size, and automatically updates achives that change

Working with an inital directory, a password, and a specified size threshold (the initial directory size, not the final archive size), create a set of files which are both compressed and encrypted. The recovery script will also be created. Further updates to the archived directory, to include files in the subdirectory, will be compared to the archives which were already created. Only the archives which need to be changed, will be changed.


Example:
./hash_backup -s dir_to_backup/ -d . -p "My Password"

Which will yield a directory of .bgb files.


To extract, a restore script is also created in the directory:

for z in *.bgb; do ./dir_to_backup_extract.sh "$z" "My Password"; done

This will recover the entire archive.
