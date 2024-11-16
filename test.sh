#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Function to run test case and compare results
run_test() {
    local test_name=$1
    local cmd1=$2
    local cmd2=$3
    
    # Create temporary files for storing outputs and exit codes
    local tmp_out1=$(mktemp)
    local tmp_out2=$(mktemp)
    local exit1_file=$(mktemp)
    local exit2_file=$(mktemp)
    
    # Run both commands and store their outputs and exit codes
    eval "$cmd1" > "$tmp_out1" 2>/dev/null
    echo $? > "$exit1_file"
    eval "$cmd2" > "$tmp_out2" 2>/dev/null
    echo $? > "$exit2_file"
    
    # Compare outputs and exit codes
    local exit1=$(cat "$exit1_file")
    local exit2=$(cat "$exit2_file")
    
    echo "Test $test_name:"
    if diff "$tmp_out1" "$tmp_out2" >/dev/null && [ "$exit1" = "$exit2" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}KO${NC}"
        echo "Expected output (shell):"
        cat "$tmp_out2"
        echo "Your output (pipex):"
        cat "$tmp_out1"
        echo "Expected exit code: $exit2"
        echo "Your exit code: $exit1"
    fi
    echo "----------------------------------------"
}

# Test cases
echo "Starting pipex tests..."

# Test 1: sleep commands
run_test "Sleep Commands" \
    "valgrind -q ./pipex infile \"/bin/sleep 5\" \"/bin/sleep 3\" outfile; echo \$?" \
    "< infile /bin/sleep 5 | /bin/sleep 3 > outfile; echo \$?"

# Test 2: ls and cat
run_test "ls and cat" \
    "valgrind -q ./pipex infile \"/bin/ls\" \"/bin/cat\" outfile; echo \$?; cat outfile" \
    "< infile ls | cat > outfile; echo \$?; cat outfile"

# Test 3: ls -l and cat
run_test "ls -l and cat" \
    "valgrind -q ./pipex infile \"/bin/ls -l\" \"/bin/cat\" outfile; echo \$?; cat outfile" \
    "< infile ls -l | cat > outfile; echo \$?; cat outfile"

# Test 4: sleep and ls
run_test "sleep and ls" \
    "valgrind -q ./pipex infile \"/bin/sleep 9\" \"/bin/ls\" outfile; echo \$?; cat outfile" \
    "< infile sleep 9 | ls > outfile; echo \$?; cat outfile"

# Test 5: cat and non-existent command
run_test "cat and non-existent command" \
    "valgrind -q ./pipex infile /bin/cat /bin/als outfile; echo \$?; cat outfile" \
    "< infile cat | als > outfile; echo \$?; cat outfile"

# Test 6: non-existent commands and files
run_test "non-existent everything" \
    "valgrind -q ./pipex ianfile saleep saleep outfile42; echo \$?; cat outfile" \
    "< ianfile saleep | saleep > outfile42; echo \$?; cat outfile42"

echo "All tests completed."

# valgrind -q ./pipex infile "/bin/sleep 5" "/bin/sleep 3" outfile; echo $?
# < infile /bin/sleep 5 | /bin/sleep 3 > outfile; echo $?

# valgrind -q ./pipex infile "/bin/ls" "/bin/cat" outfile; echo $?;cat outfile
# < infile ls | cat > outfile; echo $?;cat outfile

# valgrind -q ./pipex infile "/bin/ls -l" "/bin/cat" outfile; echo $?;cat outfile
# < infile ls -l | cat > outfile; echo $?;cat outfile

# valgrind -q ./pipex infile "/bin/sleep 9" "/bin/ls" outfile; echo $?;cat outfile
# < infile sleep 9 | ls > outfile; echo $?;cat outfile

# valgrind -q ./pipex infile /bin/cat /bin/als outfile; echo $?;cat outfile
# < infile cat | als > outfile; echo $?;cat outfile

# valgrind -q ./pipex ianfile saleep saleep outfile42; echo $?;cat outfile
# < ianfile saleep | saleep > outfile42; echo $?;cat outfile42
