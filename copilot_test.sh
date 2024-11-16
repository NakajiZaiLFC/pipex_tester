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
    
    echo "テスト $test_name:"
    if command -v diff >/dev/null 2>&1 && diff "$tmp_out1" "$tmp_out2" >/dev/null && [ "$exit1" = "$exit2" ]; then
        echo -e "${GREEN}成功${NC}"
        echo "期待される出力 (シェル):"
        if command -v cat >/dev/null 2>&1; then
            cat "$tmp_out2"
        else
            echo "catコマンドが見つかりません"
        fi
        echo "あなたの出力 (pipex):"
        if command -v cat >/dev/null 2>&1; then
            cat "$tmp_out1"
        else
            echo "catコマンドが見つかりません"
        fi
        echo "期待される終了コード: $exit2"
        echo "あなたの終了コード: $exit1"
    else
        echo -e "${RED}失敗${NC}"
        echo "期待される出力 (シェル):"
        if command -v cat >/dev/null 2>&1; then
            cat "$tmp_out2"
        else
            echo "catコマンドが見つかりません"
        fi
        echo "あなたの出力 (pipex):"
        if command -v cat >/dev/null 2>&1; then
            cat "$tmp_out1"
        else
            echo "catコマンドが見つかりません"
        fi
        echo "期待される終了コード: $exit2"
        echo "あなたの終了コード: $exit1"
    fi
    echo "----------------------------------------"
}

# Test cases
echo "pipexテストを開始します..."

# Test 1: sleep commands
run_test "Sleep Commands" \
    "valgrind -q ./pipex infile \"/bin/sleep 5\" \"/bin/sleep 3\" outfile; echo \$?" \
    "< infile /bin/sleep 5 | /bin/sleep 3 > outfile; echo \$?"

echo

# Test 2: ls and cat
run_test "ls and cat" \
    "valgrind -q ./pipex infile \"/bin/ls\" \"/bin/cat\" outfile; echo \$?; cat outfile" \
    "< infile ls | cat > outfile; echo \$?; cat outfile"

echo

# Test 3: ls -l and cat
run_test "ls -l and cat" \
    "valgrind -q ./pipex infile \"/bin/ls -l\" \"/bin/cat\" outfile; echo \$?; cat outfile" \
    "< infile ls -l | cat > outfile; echo \$?; cat outfile"

echo

# Test 4: sleep and ls
run_test "sleep and ls" \
    "valgrind -q ./pipex infile \"/bin/sleep 9\" \"/bin/ls\" outfile; echo \$?; cat outfile" \
    "< infile sleep 9 | ls > outfile; echo \$?; cat outfile"

echo

# Test 5: cat and non-existent command
run_test "cat and non-existent command" \
    "valgrind -q ./pipex infile /bin/cat /bin/als outfile; echo \$?; cat outfile" \
    "< infile cat | als > outfile; echo \$?; cat outfile"

echo

# Test 6: non-existent commands and files
run_test "non-existent everything" \
    "valgrind -q ./pipex ianfile saleep saleep outfile42; echo \$?; cat outfile" \
    "< ianfile saleep | saleep > outfile42; echo \$?; cat outfile42"

echo

# Test 7: cat and grep
run_test "cat and grep" \
    "valgrind -q ./pipex infile cat \"grep 'a'\" outfile; echo \$?" \
    "< infile cat | grep 'a' > outfile; echo \$?"

echo

# Error handling tests
run_test "入力ファイルが存在せず、出力ファイルの権限が拒否されました" \
    "valgrind -q ./pipex non_existent_file cmd1 cmd2 outfile; echo \$?" \
    "< non_existent_file cmd1 | cmd2 > outfile; echo \$?"

echo

run_test "入力ファイルの権限が拒否され、出力ファイルの権限が拒否されました" \
    "valgrind -q ./pipex infile cmd1 cmd2 outfile; echo \$?" \
    "< infile cmd1 | cmd2 > outfile; echo \$?"

echo

run_test "入力ファイルは存在するがコマンドが無効で、出力ファイルの権限が拒否されました" \
    "valgrind -q ./pipex infile invalid_cmd cmd2 outfile; echo \$?" \
    "< infile invalid_cmd | cmd2 > outfile; echo \$?"

echo

run_test "入力ファイルが存在せず、出力ファイルが存在するがコマンドが無効です" \
    "valgrind -q ./pipex non_existent_file cmd1 invalid_cmd outfile; echo \$?" \
    "< non_existent_file cmd1 | invalid_cmd > outfile; echo \$?"

echo

run_test "入力ファイルの権限が拒否され、出力ファイルが存在するがコマンドが無効です" \
    "valgrind -q ./pipex infile cmd1 invalid_cmd outfile; echo \$?" \
    "< infile cmd1 | invalid_cmd > outfile; echo \$?"

echo

run_test "両方のコマンドが無効です" \
    "valgrind -q ./pipex infile invalid_cmd1 invalid_cmd2 outfile; echo \$?" \
    "< infile invalid_cmd1 | invalid_cmd2 > outfile; echo \$?"

echo

run_test "出力リダイレクトエラー" \
    "valgrind -q ./pipex infile cmd1 cmd2 > > outfile; echo \$?" \
    "< infile cmd1 | cmd2 > > outfile; echo \$?"

echo

run_test "ファイルディスクリプタが1024を超えています" \
    "valgrind -q ./pipex infile cmd1 cmd2 1025> outfile; echo \$?" \
    "< infile cmd1 | cmd2 1025> outfile; echo \$?"

echo

run_test "ヒアドキュメント" \
    "valgrind -q ./pipex_bonus infile cmd1 cmd2 << EOF; echo \$?" \
    "< infile cmd1 | cmd2 << EOF; echo \$?"

echo

run_test "追加の権限チェック" \
    "valgrind -q ./pipex infile cmd1 cmd2 >> outfile; echo \$?" \
    "< infile cmd1 | cmd2 >> outfile; echo \$?"

echo

run_test "パス関連のチェック" \
    "valgrind -q ./pipex infile cmd1 cmd2 > /path/to/file; echo \$?" \
    "< infile cmd1 | cmd2 > /path/to/file; echo \$?"

echo

run_test "親ディレクトリの権限チェック" \
    "valgrind -q ./pipex infile cmd1 cmd2 > ../file; echo \$?" \
    "< infile cmd1 | cmd2 > ../file; echo \$?"

echo

run_test "PATHを解除して絶対パスをチェック" \
    "unset $PATH; valgrind -q ./pipex infile /bin/ls /bin/cat outfile; echo \$?" \
    "unset $PATH; < infile /bin/ls | /bin/cat > outfile; echo \$?"

echo

echo "すべてのテストが完了しました。"


# #!/bin/bash

# # Colors for output
# GREEN='\033[0;32m'
# RED='\033[0;31m'
# NC='\033[0m'

# # Function to run test case and compare results
# run_test() {
#     local test_name=$1
#     local cmd1=$2
#     local cmd2=$3
    
#     # Create temporary files for storing outputs and exit codes
#     local tmp_out1=$(mktemp)
#     local tmp_out2=$(mktemp)
#     local exit1_file=$(mktemp)
#     local exit2_file=$(mktemp)
    
#     # Run both commands and store their outputs and exit codes
#     eval "$cmd1" > "$tmp_out1" 2>/dev/null
#     echo $? > "$exit1_file"
#     eval "$cmd2" > "$tmp_out2" 2>/dev/null
#     echo $? > "$exit2_file"
    
#     # Compare outputs and exit codes
#     local exit1=$(cat "$exit1_file")
#     local exit2=$(cat "$exit2_file")
    
#     echo "テスト $test_name:"
#     if command -v diff >/dev/null 2>&1 && diff "$tmp_out1" "$tmp_out2" >/dev/null && [ "$exit1" = "$exit2" ]; then
#         echo -e "${GREEN}成功${NC}"
#     else
#         echo -e "${RED}失敗${NC}"
#         echo "期待される出力 (シェル):"
#         if command -v cat >/dev/null 2>&1; then
#             cat "$tmp_out2"
#         else
#             echo "catコマンドが見つかりません"
#         fi
#         echo "あなたの出力 (pipex):"
#         if command -v cat >/dev/null 2>&1; then
#             cat "$tmp_out1"
#         else
#             echo "catコマンドが見つかりません"
#         fi
#         echo "期待される終了コード: $exit2"
#         echo "あなたの終了コード: $exit1"
#     fi
#     echo "----------------------------------------"
# }

# # Test cases
# echo "pipexテストを開始します..."

# # Test 1: sleep commands
# run_test "Sleep Commands" \
#     "valgrind -q ./pipex infile "/bin/sleep 5" "/bin/sleep 3" outfile; echo $?" \
#     "< infile /bin/sleep 5 | /bin/sleep 3 > outfile; echo $?"

# echo

# # Test 2: ls and cat
# run_test "ls and cat" \
#     "valgrind -q ./pipex infile "/bin/ls" "/bin/cat" outfile; echo $?; cat outfile" \
#     "< infile ls | cat > outfile; echo $?; cat outfile"

# echo

# # Test 3: ls -l and cat
# run_test "ls -l and cat" \
#     "valgrind -q ./pipex infile "/bin/ls -l" "/bin/cat" outfile; echo $?; cat outfile" \
#     "< infile ls -l | cat > outfile; echo $?; cat outfile"

# echo

# # Test 4: sleep and ls
# run_test "sleep and ls" \
#     "valgrind -q ./pipex infile "/bin/sleep 9" "/bin/ls" outfile; echo $?; cat outfile" \
#     "< infile sleep 9 | ls > outfile; echo $?; cat outfile"

# echo

# # Test 5: cat and non-existent command
# run_test "cat and non-existent command" \
#     "valgrind -q ./pipex infile /bin/cat /bin/als outfile; echo $?; cat outfile" \
#     "< infile cat | als > outfile; echo $?; cat outfile"

# echo

# # Test 6: non-existent commands and files
# run_test "non-existent everything" \
#     "valgrind -q ./pipex ianfile saleep saleep outfile42; echo $?; cat outfile" \
#     "< ianfile saleep | saleep > outfile42; echo $?; cat outfile42"

# echo

# # Test 7: cat and grep
# run_test "cat and grep" \
#     "valgrind -q ./pipex infile cat "grep 'a'" outfile; echo $?" \
#     "< infile cat | grep 'a' > outfile; echo $?"

# echo

# # Error handling tests
# run_test "入力ファイルが存在せず、出力ファイルの権限が拒否されました" \
#     "valgrind -q ./pipex non_existent_file cmd1 cmd2 outfile; echo $?" \
#     "< non_existent_file cmd1 | cmd2 > outfile; echo $?"

# echo

# run_test "入力ファイルの権限が拒否され、出力ファイルの権限が拒否されました" \
#     "valgrind -q ./pipex infile cmd1 cmd2 outfile; echo $?" \
#     "< infile cmd1 | cmd2 > outfile; echo $?"

# echo

# run_test "入力ファイルは存在するがコマンドが無効で、出力ファイルの権限が拒否されました" \
#     "valgrind -q ./pipex infile invalid_cmd cmd2 outfile; echo $?" \
#     "< infile invalid_cmd | cmd2 > outfile; echo $?"

# echo

# run_test "入力ファイルが存在せず、出力ファイルが存在するがコマンドが無効です" \
#     "valgrind -q ./pipex non_existent_file cmd1 invalid_cmd outfile; echo $?" \
#     "< non_existent_file cmd1 | invalid_cmd > outfile; echo $?"

# echo

# run_test "入力ファイルの権限が拒否され、出力ファイルが存在するがコマンドが無効です" \
#     "valgrind -q ./pipex infile cmd1 invalid_cmd outfile; echo $?" \
#     "< infile cmd1 | invalid_cmd > outfile; echo $?"

# echo

# run_test "両方のコマンドが無効です" \
#     "valgrind -q ./pipex infile invalid_cmd1 invalid_cmd2 outfile; echo $?" \
#     "< infile invalid_cmd1 | invalid_cmd2 > outfile; echo $?"

# echo

# run_test "出力リダイレクトエラー" \
#     "valgrind -q ./pipex infile cmd1 cmd2 > > outfile; echo $?" \
#     "< infile cmd1 | cmd2 > > outfile; echo $?"

# echo

# run_test "ファイルディスクリプタが1024を超えています" \
#     "valgrind -q ./pipex infile cmd1 cmd2 1025> outfile; echo $?" \
#     "< infile cmd1 | cmd2 1025> outfile; echo $?"

# echo

# run_test "ヒアドキュメント" \
#     "valgrind -q ./pipex_bonus infile cmd1 cmd2 << EOF; echo $?" \
#     "< infile cmd1 | cmd2 << EOF; echo $?"

# echo

# run_test "追加の権限チェック" \
#     "valgrind -q ./pipex infile cmd1 cmd2 >> outfile; echo $?" \
#     "< infile cmd1 | cmd2 >> outfile; echo $?"

# echo

# run_test "パス関連のチェック" \
#     "valgrind -q ./pipex infile cmd1 cmd2 > /path/to/file; echo $?" \
#     "< infile cmd1 | cmd2 > /path/to/file; echo $?"

# echo

# run_test "親ディレクトリの権限チェック" \
#     "valgrind -q ./pipex infile cmd1 cmd2 > ../file; echo $?" \
#     "< infile cmd1 | cmd2 > ../file; echo $?"

# echo

# run_test "PATHを解除して絶対パスをチェック" \
#     "unset $PATH; valgrind -q ./pipex infile /bin/ls /bin/cat outfile; echo $?" \
#     "unset $PATH; < infile /bin/ls | /bin/cat > outfile; echo $?"

# echo

# echo "すべてのテストが完了しました。"