# Add files to commit (pre-requisite)
git add .

# Create commit message
## Normal interactive mode: shows proposed commit message and offers choices:
git-gen-commit

c - Commit the proposed commit message (accept and create the commit)
e - Edit the proposed commit message before committing in vi (allows you to modify it. :i for insert, esc + :q! for exit)
r - Regenerate a new commit message (get a different suggestion)
d - Discard the proposal (exit without committing)

--verbose — show the diff for each file during analysis
--only-message — print only the final commit message (useful for scripting/CI)

# Use --help for more info
git-gen-commit --help

# Use other models 
git-gen-commit --model qwen2.5-coder:1.5b

### DEV 

#### Reset last commit
git reset --soft HEAD~1

#### Reset git add
git restore <file>

#### Applying code changes in .sh file
cp git-gen-commit.sh ~/bin/git-gen-commit
chmod +x ~/bin/git-gen-commit