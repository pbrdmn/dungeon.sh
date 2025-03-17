#!/bin/bash

# title: Dungeon Game

# Initial Setup
trap ctrl_c INT
dungeon_width=40
dungeon_height=15
MAX_PLAYER_HEALTH=10
PLAYING=true
player_x=0
player_y=0
wall_percentage=20 # Percentage of cells that should be walls
wall_break_chance=50 # Chance of breaking a wall
player_health=$MAX_PLAYER_HEALTH
player_gold=0
xp=0
player_level=1
level_xp=0
update_message=""

# Function to get terminal dimensions
get_terminal_dimensions() {
    local term_width=$(tput cols)
    local term_height=$(tput lines)
    dungeon_width=$((term_width - 1))  # Adjust for padding
    dungeon_height=$((term_height - 5)) # Adjust for status bar and other UI elements
}

# Function to generate the dungeon layout
generate_dungeon() {
    dungeon=()
    for ((y=0; y<dungeon_height; y++)); do
        row=""
        for ((x=0; x<dungeon_width; x++)); do
            if [[ $((RANDOM % 100)) -lt $wall_percentage ]]; then
		        if [[ ($x -eq $player_x && $y -eq $player_y) || ($x -eq $monster_x && $y -eq $monster_y) ]]; then
                    row+="."
		        else
                    row+="#"
                fi
            else
                row+="."
            fi
        done
        dungeon+=("$row")
    done
}

# Function to display the dungeon
display_dungeon() {
    echo "Dungeon:"
    for ((y=0; y<dungeon_height; y++)); do
        for ((x=0; x<dungeon_width; x++)); do
            if [[ ${dungeon[$y]:$x:1} == "#" ]]; then
                echo -en "\033[0;1m▉\033[0m"
            elif [[ $x -eq $player_x && $y -eq $player_y ]]; then
                echo -en "\033[32;1m@\033[0m"
            elif [[ $x -eq $monster_x && $y -eq $monster_y ]]; then
                echo -en "\033[31;1m&\033[0m"
            else
                echo -n " "
            fi
        done
        echo
    done

    health_colour="\033[32;1m"
    if [[ $player_health -lt 5 ]]; then
        health_colour="\033[31;1m"
    fi

    echo -e "HP: $health_colour$player_health\033[0m | GP: \033[33;1m$player_gold\033[0m | LVL: \033[35;1m$player_level\033[0m | XP: \033[36;1m$xp\033[0m"

    echo -e "$update_message"
    update_message=""
}

# Function to handle player movement
move_player() {
    local direction=$1
    local new_x=$player_x
    local new_y=$player_y
    case $direction in
        w)
            ((new_y--))
            ;;
        W)
            while (check_space_is_empty $new_x $((new_y-1))); do
                update_message="${update_message}."
                ((new_y--))
            done
            player_y=$new_y
            return
            ;;
        s)
            ((new_y++))
            ;;
        S)
            while (check_space_is_empty $new_x $((new_y+1))); do
                update_message="${update_message}."
                ((new_y++))
            done
            player_y=$new_y
            return
            ;;
        a)
            ((new_x--))
            ;;
        A)
            while (check_space_is_empty $((new_x-1)) $new_y); do
                update_message="${update_message}."
                ((new_x--))
            done
            player_x=$new_x
            return
            ;;
        d)
            ((new_x++))
            ;;
        D)
            while (check_space_is_empty $((new_x+1)) $new_y); do
                update_message="${update_message}."
                ((new_x++))
            done
            player_x=$new_x
            return
            ;;
        *)
            update_message="Invalid direction! "
            return
            ;;
    esac

    # Check if the new position is within bounds
    if [[ $new_x -ge 0 && $new_x -lt $dungeon_width && $new_y -ge 0 && $new_y -lt $dungeon_height ]]; then
        if [[ ${dungeon[$new_y]:$new_x:1} == "#" ]]; then
            update_message="${update_message}You attack a wall! "
            destroy_wall $new_x $new_y
        elif [[ $new_x -eq $monster_x && $new_y -eq $monster_y ]]; then
            update_message="${update_message}You attack the monster! "
            attack_monster
        else
            # Move smoothly to the new location
            player_x=$new_x
            player_y=$new_y
        fi
    fi
}

# Function to destroy a wall
destroy_wall() {
    local x=$1
    local y=$2
    if [[ $((RANDOM % 100)) -lt $wall_break_chance ]]; then
        dungeon[$y]=$(echo "${dungeon[$y]}" | sed "s/./ /$((x + 1))")
        if [[ $((RANDOM % 100)) -lt 50 ]]; then
            # 50% chance of taking damage
            ((player_health--))
            update_message="${update_message}\033[31;1mYou were hurt by the falling wall\033[0m. "
        elif [[ $((RANDOM % 100)) -lt 55 ]]; then
            # 5% chance of finding gold
            ((player_gold++))
            update_message="${update_message}\033[33;1mYou found a gold coin\033[0m. "
        fi
    fi
}

# Function to check if a space is empty
check_space_is_empty() {
    echo "Checking space $1, $2"
    local x=$1
    local y=$2
    if [[ $x -lt 0 || $x -ge $dungeon_width || $y -lt 0 || $y -ge $dungeon_height ]]; then
        echo "Out of bounds"
        return 1 # Out of bounds
    elif [[ ${dungeon[$y]:$x:1} == "#" ]]; then
        echo "Wall"
        return 1 # Wall
    elif [[ $x -eq $monster_x && $y -eq $monster_y ]]; then
        echo "Monster"
        return 1 # Monster
    else
        echo "Empty"
        return 0
    fi
}

# Function to handle combat with the monster
attack_monster() {
    if [[ $((RANDOM % 100)) -lt 75 ]]; then
        update_message="${update_message}You defeat the monster! "
        defeat_monster
    else
        update_message="${update_message}You miss. "
        # Monster's turn to attack
        if [[ $((RANDOM % 100)) -lt 75 ]]; then
            update_message="${update_message}\033[31;1mThe monster hits you for ${player_level} damage!\033[0m "
            player_health=$((player_health-player_level))
        else
            update_message="${update_message}The monster missed. "
        fi
    fi

    # Check the player's health after fighting
    if [[ $player_health -le 0 ]]; then
        update_message="${update_message}\033[31;1mYou have been defeated!!\033[0m "
        PLAYING=false
    fi
}

# Function to handle player defeating an monster
defeat_monster() {
    # Gain experience points
    ((xp++))
    ((level_xp++))
    
    # Level up
    if [[ $level_xp -eq $((player_level * 10)) ]]; then
        ((player_level++))
        level_xp=0

        # Increase player health and generate a new dungeon layout
        ((MAX_PLAYER_HEALTH++))
        player_health=$MAX_PLAYER_HEALTH
        generate_dungeon
    fi

    if [[ $((RANDOM % 100)) -lt 10 ]]; then # 10% chance of finding 3 gold
        ((player_gold=player_gold+3))
        update_message="${update_message}You found 3 gold coins. "
    elif [[ $((RANDOM % 100)) -lt 30 ]]; then # 20% chance of finding 2 gold
        ((player_gold=player_gold+2))
        update_message="${update_message}You found 2 gold coins. "
    elif [[ $((RANDOM % 100)) -lt 80 ]]; then # 50% chance of finding 1 gold
        ((player_gold=player_gold+1))
        update_message="${update_message}You found a gold coin. "
    fi
    spawn_new_monster
}

# Function to spawn a new monster
spawn_new_monster() {
    while true; do
        local x=$((RANDOM % dungeon_width))
        local y=$((RANDOM % dungeon_height))
        local dx=$((x - player_x))
        local dy=$((y - player_y))
        local distance=$((dx * dx + dy * dy))

        # Ensure the monster is not placed on a wall and is at least 5 spaces away from the player
        if [[ ${dungeon[$y]:$x:1} != "#" && $distance -ge 25 ]]; then
            monster_x=$x
            monster_y=$y
            break
        fi
    done
}

# Function to show game summary
game_summary() {
    clear
    echo "Level Reached: $player_level"
    echo "Monsters Defeated: $xp"
    echo "Gold Accumulated: $player_gold"
}

# Function to quit
ctrl_c() {
    PLAYING=false
    game_summary
    exit
}

# Initial setup
# get_terminal_dimensions
player_x=$dungeon_width/2
player_y=$dungeon_height/2
generate_dungeon
spawn_new_monster

# Main game loop
while $PLAYING; do
    clear
    display_dungeon

    read -n 1 -p "Move (w/a/s/d): " move
    echo
    move_player $move
done

game_summary
