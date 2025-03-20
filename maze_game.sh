#!/usr/bin/env bash

source ./maze_generator.sh  # Your maze generator file

width=21
height=11
player_x=11
player_y=5

generate_new_maze() {
    maze=()
    exit_x=0
    exit_y=0
    while IFS= read -r line; do
        if [[ $line == EXIT_COORDS* ]]; then
            read -r _ exit_x exit_y <<< "$line"
        else
            maze+=("$line")
        fi
    done < <(./maze_generator.sh $width $height $player_x $player_y)
}

draw_maze() {
    clear
    for ((y=0; y<${#maze[@]}; y++)); do
        for ((x=0; x<${#maze[y]}; x++)); do
            if ((x == player_x && y == player_y)); then
                printf "@"
            elif ((x == exit_x && y == exit_y)); then
                printf "X"
            elif [[ "${maze[y]:x:1}" == "#" ]]; then
                printf "█"
            elif [[ "${maze[y]:x:1}" == " " ]]; then
                printf " "
            else
                printf "%s" "${maze[y]:x:1}"
            fi
        done
        echo
    done
}

find_exit() {
    for ((y=0; y<${#maze[@]}; y++)); do
        for ((x=0; x<${#maze[y]}; x++)); do
            if [[ ${maze[y]:x:1} == "X" ]]; then
                exit_x=$x
                exit_y=$y
                return
            fi
        done
    done
}

# Read arrow key input
read_input() {
    IFS= read -rsn1 key
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 key
        case "$key" in
            "[A") dy=-1 ;; # Up
            "[B") dy=1 ;;  # Down
            "[C") dx=1 ;;  # Right
            "[D") dx=-1 ;; # Left
        esac
    fi
}

# Start the game
generate_new_maze
find_exit

while true; do
    draw_maze
    dx=0
    dy=0
    read_input
    next_x=$((player_x + dx))
    next_y=$((player_y + dy))
    if [[ ${maze[next_y]:next_x:1} != "#" ]]; then
        player_x=$next_x
        player_y=$next_y
    fi
    if ((player_x == exit_x && player_y == exit_y)); then
        echo "You reached the exit! Generating new maze..."
        sleep 1
        generate_new_maze
        find_exit
    fi
done

