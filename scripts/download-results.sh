ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='work' -cf /tmp/archive.tar ."
scp mimeul@cluster.s3it.uzh.ch:/tmp/archive.tar "$env:USERPROFILE\kansasii\downloads\"
cd "$env:USERPROFILE\kansasii\downloads"
tar -xf archive.tar



# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && find . -name '*.html' | tar -cf /tmp/htmls.tar -T -"
# scp mimeul@cluster.s3it.uzh.ch:/tmp/htmls.tar "$env:USERPROFILE\kansasii\downloads\"
# cd "$env:USERPROFILE\kansasii\downloads"
# tar -xf htmls.tar

# ssh mimeul@cluster.s3it.uzh.ch "cd /shares/sander.imm.uzh/MM/kansasii/output && tar --exclude='./*/work' -cf /tmp/archive.tar ."
