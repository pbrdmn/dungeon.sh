generate_maze() {
    local width=$1
    local height=$2
    local start_x=$3
    local start_y=$4
    local -a maze
    local -a branch_endings=()
    local exit_x exit_y

    # Ensure odd dimensions for proper maze structure
    (( width % 2 == 0 )) && (( width++ ))
    (( height % 2 == 0 )) && (( height++ ))

    # Initialize maze with walls
    for (( y=0; y<height; y++ )); do
        maze[y]="$(printf '#%.0s' $(seq 1 $width))"
    done

    # Recursive function to carve paths
    carve() {
        local x=$1
        local y=$2
        maze[y]="${maze[y]:0:x} ${maze[y]:x+1}"
        local directions=(0 1 2 3)
        local carved=false

        # Shuffle directions
        for (( i=0; i<4; i++ )); do
            local j=$(( RANDOM % 4 ))
            temp=${directions[i]}
            directions[i]=${directions[j]}
            directions[j]=$temp
        done

        for dir in "${directions[@]}"; do
            local nx=$x
            local ny=$y
            case $dir in
                0) (( nx -= 2 )) ;; # Left
                1) (( nx += 2 )) ;; # Right
                2) (( ny -= 2 )) ;; # Up
                3) (( ny += 2 )) ;; # Down
            esac
            if (( nx > 0 && nx < width-1 && ny > 0 && ny < height-1 )); then
                if [[ ${maze[ny]:nx:1} == "#" ]]; then
                    maze[$(((ny+y)/2))]="${maze[$(((ny+y)/2))]:0:$(((nx+x)/2))} ${maze[$(((ny+y)/2))]:$(((nx+x)/2))+1}"
                    carve $nx $ny
                    carved=true
                fi
            fi
        done

        # If no direction was carved, mark as a potential exit point
        if ! $carved; then
            branch_endings+=("$x $y")
        fi
    }

    # Validate and adjust starting point
    (( start_x % 2 == 0 )) && (( start_x-- ))
    (( start_y % 2 == 0 )) && (( start_y-- ))

    # Start carving from the provided starting coordinates
    carve $start_x $start_y

    # Choose a random branch ending as the exit
    if (( ${#branch_endings[@]} > 0 )); then
        local exit_index=$(( RANDOM % ${#branch_endings[@]} ))
        local exit_coords=(${branch_endings[$exit_index]})
        exit_x=${exit_coords[0]}
        exit_y=${exit_coords[1]}
    fi

    # Output the maze without marking start/end so the game can render them dynamically
    for row in "${maze[@]}"; do
        echo "$row"
    done

    # Export exit coordinates for the game
    echo "EXIT_COORDS $exit_x $exit_y"
}

# Only run the example if the script is executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    generate_maze 21 11 11 5
fi
