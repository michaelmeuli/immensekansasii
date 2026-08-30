


# By default the output is always written in the current directory
cd /shares/sander.imm.uzh/MM/kansasii/output
bash /shares/sander.imm.uzh/MM/kansasii/immensekansasii/run_IMMENSE.sh -j test_run -t fq_PE -r test_run -i /shares/sander.imm.uzh/MM/kansasii/immensekansasii/data/test_dataset




ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='work' -cf /tmp/archive.tar ."
scp mimeul@cluster.s3it.uzh.ch:/tmp/archive.tar "$env:USERPROFILE\kansasii\downloads\"
cd "$env:USERPROFILE\kansasii\downloads"
tar -xf archive.tar



# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && find . -name '*.html' | tar -cf /tmp/htmls.tar -T -"
# scp mimeul@cluster.s3it.uzh.ch:/tmp/htmls.tar "$env:USERPROFILE\kansasii\downloads\"
# cd "$env:USERPROFILE\kansasii\downloads"
# tar -xf htmls.tar

# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='./*/work' -cf /tmp/archive.tar ."