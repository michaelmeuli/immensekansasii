# 1. Create a new branch off the target branch (keeps that branch itself untouched)
cd /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii
git branch master-fasta-fix-test master

# 2. Check it out to apply changes (creating the branch alone doesn't check it out)
git checkout master-fasta-fix-test
git cherry-pick c2ad8c452e489550

# 3. Switch the main checkout back to your actual working branch
git checkout kansasii

# 4. Create a worktree for the new branch -- a separate directory, same .git,
#    so both branches are on disk simultaneously without disturbing this checkout
git worktree add /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii-fasta-fix-test master-fasta-fix-test

# 5. Run the pipeline from the worktree's own path
mkdir -p /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test
cd /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test
bash /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii-fasta-fix-test/run_IMMENSE.sh \
  -j job_relevant_species_tree_run_master_fasta_fix_test \
  -t fasta -r relevant_species_tree_run_master_fasta_fix_test \
  -i /shares/sander.imm.uzh/MM/kansasii/data/gtdb_genomes/Mycobacteriaceae/selected_relevant_species


# --- cleanup, once you're done with the test ---

# Remove the worktree (only after any job launched from it has finished --
# its files are read for the job's whole runtime, not just at submit)
cd /shares/sander.imm.uzh/MM/kansasii/repos/immensekansasii
git worktree remove immensekansasii-fasta-fix-test

# Delete the test branch, if you don't need to keep it around
git branch -D master-fasta-fix-test

# Remove the test run's output directory
rm -rf /shares/sander.imm.uzh/MM/kansasii/output/relevant_species_tree_run_master_fasta_fix_test

Note: git worktree remove refuses if the working tree isn't clean or a process still has files open there — check squeue/sacct for the job first (that's what I did for the master worktree removal earlier).