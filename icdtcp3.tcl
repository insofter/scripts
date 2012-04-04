set icdtcp3_tftp_dir "$env(ICDTCP3_TFTP_DIR)"

set bootstrapFile "$icdtcp3_tftp_dir/at91bootstrap-icdtcp3.bin"
set ubootFile "$icdtcp3_tftp_dir/u-boot-icdtcp3.bin"	
set ubootAddr 0x00080000

puts "-I- === Initialize the NAND access ==="
NANDFLASH::Init

puts "-I- === Erase all the NAND flash blocs and test the erasing ==="
NANDFLASH::EraseAllNandFlash

puts "-I- === Load the bootstrap: nandflash_at91sam9-ek in the first sector ==="
NANDFLASH::sendBootFile $bootstrapFile

puts "-I- === Load the u-boot in the next sectors ==="
send_file {NandFlash} "$ubootFile" $ubootAddr 0 
