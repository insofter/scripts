set icdtcp3_tftp_dir "$env(ICDTCP3_TFTP_DIR)"
set icdtcp3_scripts_dir "$env(ICDTCP3_SCRIPTS_DIR)"

set bootstrapFile "$icdtcp3_tftp_dir/at91bootstrap.bin"
set ubootFile "$icdtcp3_tftp_dir/u-boot.bin"
set resetFile "$icdtcp3_scripts_dir/icdtcp3-reset.bin"
set ubootAddr 0x00080000

puts "-I- === Initialize the NAND access ==="
NANDFLASH::Init

puts "-I- === Erase all the NAND flash blocs and test the erasing ==="
NANDFLASH::EraseAllNandFlash

puts "-I- === Load the bootstrap: nandflash_at91sam9-ek in the first sector ==="
NANDFLASH::sendBootFile $bootstrapFile

puts "-I- === Load the u-boot in the next sectors ==="
send_file {NandFlash} "$ubootFile" $ubootAddr 0

puts "-I- === Reset device ==="
send_file {SDRAM} "$resetFile" 0x21F00000 0
TCL_Go $target(handle) 0x21F00000 0
