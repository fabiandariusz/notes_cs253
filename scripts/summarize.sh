# simple bash script to summarize lecture videos

#!/bin/bash
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <filename.txt>"
  exit 1
fi

readonly filename="$1"

if [ ! -f "$filename" ]; then
  echo "Error: File '$filename' not found."
  exit 1
fi

if [[ "$filename" != *.txt ]] && [[ "$filename" != *.TXT ]]; then
  echo "Error: Input file must be a .txt file."
  exit 1
fi

echo "Summarizing content of $filename..."

# Extract the directory and base name of the input file
input_dir=$(dirname -- "$filename")
# Extract the base name of the file (e.g., "document" from "/path/to/document.txt")
base_filename=$(basename -- "$filename" .txt)
output_filename="${input_dir}/${base_filename}_summary.txt"
output_filename01="${input_dir}/${base_filename}_Lecture_summary.txt"
output_filename02="${input_dir}/${base_filename}_youtube_summary.txt"

# Create a temporary file for logging completion messages
log_file=$(mktemp)

# Ensure the log file is cleaned up on exit
trap 'rm -f "$log_file"' EXIT

run_summarization() {
  local input_file="$1"
  local pattern="$2"
  local output_file="$3"
  local message
  cat "$input_file" | fabric-ai -p "$pattern" > "$output_file"
  case "$pattern" in
    "summarize")
      message="Overview is completed"
      ;;
    "summarize_lecture")
      message="Lecture overview completed"
      ;;
    "youtube_summary")
      message="YouTube summary completed"
      ;;
  esac
  # Write completion message to the log file instead of stdout
  echo "✓ $message for $output_file" >> "$log_file"
}

# Start summarizations in the background
run_summarization "$filename" "summarize" "$output_filename" &
pid1=$!
run_summarization "$filename" "summarize_lecture" "$output_filename01" &
pid2=$!
run_summarization "$filename" "youtube_summary" "$output_filename02" &
pid3=$!

# Function to draw a progress bar
draw_progress_bar() {
    local -r bar_size=40
    local -r num_jobs=$1
    local -r completed_jobs=$2
    local progress=$((completed_jobs * 100 / num_jobs))
    local filled_len=$((bar_size * progress / 100))
    local empty_len=$((bar_size - filled_len))

    # Build the filled and empty parts of the bar
    local filled_bar; printf -v filled_bar '%*s' "$filled_len"
    local empty_bar;  printf -v empty_bar  '%*s' "$empty_len"

    # Print the full bar, replacing spaces with block characters
    printf "\r[%s%s] %d%%" "${filled_bar// /█}" "${empty_bar// /░}" "$progress"
}

is_job_complete() {
    local pid="$1"
    local done="$2"

    if (( done == 1 )); then
        printf '1'
        return
    fi

    if ! kill -0 "$pid" &>/dev/null; then
        printf '1'
        return
    fi

    local state
    state=$(ps -p "$pid" -o stat= 2>/dev/null | tr -d '[:space:]')
    if [[ -z "$state" || "$state" == Z* ]]; then
        printf '1'
        return
    fi

    printf '0'
}

echo -n "Processing...  "
completed1=0
completed2=0
completed3=0

while (( completed1 + completed2 + completed3 < 3 )); do
    completed1=$(is_job_complete "$pid1" "$completed1")
    completed2=$(is_job_complete "$pid2" "$completed2")
    completed3=$(is_job_complete "$pid3" "$completed3")

    completed_jobs=$((completed1 + completed2 + completed3))
    draw_progress_bar 3 "$completed_jobs"
    sleep 0.1
done

# Wait for all background jobs to finish to prevent the script from exiting prematurely
wait

# Draw the final 100% progress bar on the same line and then move to a new line.
draw_progress_bar 3 3 
printf "\n"

# Output all the completion messages from the log file
cat "$log_file"

echo -e "\nAll summarizations complete."
