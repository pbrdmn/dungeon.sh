#!/bin/bash

# title: Dungeon Game

# Initial Setup
MAX_PLAYER_HEALTH=10
PLAYING=true
player_x=0
player_y=0
wall_percentage=20 # Percentage of cells that should be walls
player_health=$MAX_PLAYER_HEALTH
player_gold=0
kills=0
player_level=1
kills_this_level=0
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
            if [[ $((RANDOM % 100)) -lt $wall_percentage && $x -ne $player_x && $y -ne $player_y && $x -ne $enemy_x && $y -ne $enemy_y ]]; then
                row+="#"
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
            elif [[ $x -eq $enemy_x && $y -eq $enemy_y ]]; then
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

    echo -e "HP: $health_colour$player_health\033[0m | GP: \033[33;1m$player_gold\033[0m | LVL: \033[35;1m$player_level\033[0m | XP: \033[36;1m$kills\033[0m"

    echo -e "$update_message"
    update_message=""
}

# Function to place an entity (player, enemy) in a valid position
place_entity() {
    local entity=$1
    while true; do
        local x=$((RANDOM % dungeon_width))
        local y=$((RANDOM % dungeon_height))
        if [[ ${dungeon[$y]:$x:1} != "#" ]]; then
            case $entity in
                player)
                    player_x=$x
                    player_y=$y
                    ;;
                enemy)
                    enemy_x=$x
                    enemy_y=$y
                    ;;
            esac
            break
        fi
    done
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
        s)
            ((new_y++))
            ;;
        a)
            ((new_x--))
            ;;
        d)
            ((new_x++))
            ;;
        q)
            # Player quits
            PLAYING=false
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
        elif [[ $new_x -eq $enemy_x && $new_y -eq $enemy_y ]]; then
            update_message="${update_message}You attack the monster! "
            fight_enemy
        else
            player_x=$new_x
            player_y=$new_y
        fi
    fi
}

# Function to destroy a wall and possibly reveal an item
destroy_wall() {
    local x=$1
    local y=$2
    if [[ $((RANDOM % 100)) -lt 80 ]]; then
        dungeon[$y]=$(echo "${dungeon[$y]}" | sed "s/./ /$((x + 1))")
        if [[ $((RANDOM % 100)) -lt 10 ]]; then
            if [[ $((RANDOM % 100)) -lt 10 ]]; then
                ((player_gold++))
                update_message="${update_message}You found a gold coin. "
            else
                ((player_health--))
                update_message="${update_message}You were hurt by the falling wall. "
            fi
        fi
    fi
}

# Function to check for encounters
check_encounter() {
    if [[ $player_x -eq $enemy_x && $player_y -eq $enemy_y ]]; then
        update_message="${update_message}You encountered an enemy! "
        fight_enemy
    fi
}

# Function to handle combat with the enemy
fight_enemy() {
    if [[ $((RANDOM % 100)) -lt 75 ]]; then
        update_message="${update_message}You defeat the monster! "
        defeat_monster
    else
        update_message="${update_message}You miss. "
        # Monster's turn to attack
        if [[ $((RANDOM % 100)) -lt 75 ]]; then
            update_message="${update_message}The monster hits you! "
            ((player_health--))
        else
            update_message="${update_message}The monster missed. "
        fi
    fi

    # Check the player's health after fighting
    if [[ $player_health -le 0 ]]; then
        update_message="${update_message}You have been defeated! "
        PLAYING=false
    fi
}

# Function to handle player defeating an enemy
defeat_monster() {
    ((kills++))
    ((kills_this_level++))
    ((player_gold++))
    if [[ $kills_this_level -eq 10 ]]; then
        ((player_level++))
        ((MAX_PLAYER_HEALTH++))
        player_health=$MAX_PLAYER_HEALTH
        kills_this_level=0
        generate_dungeon
    fi
    spawn_new_enemy
}

# Function to spawn a new enemy at a random edge of the map
spawn_new_enemy() {
    local edges=("top" "bottom" "left" "right")
    local edge=${edges[$RANDOM % ${#edges[@]}]}
    case $edge in
        top)
            enemy_x=$((RANDOM % dungeon_width))
            enemy_y=1
            ;;
        bottom)
            enemy_x=$((RANDOM % dungeon_width))
            enemy_y=$((dungeon_height - 2))
            ;;
        left)
            enemy_x=1
            enemy_y=$((RANDOM % dungeon_height))
            ;;
        right)
            enemy_x=$((dungeon_width - 2))
            enemy_y=$((RANDOM % dungeon_height))
            ;;
    esac

    # Ensure the enemy is not placed on a wall
    if [[ ${dungeon[$enemy_y]:$enemy_x:1} == "#" ]]; then
        dungeon[$enemy_y]=$(echo "${dungeon[$enemy_y]}" | sed "s/./ /$((enemy_x + 1))")
    fi
}

# Main game loop
get_terminal_dimensions
generate_dungeon
place_entity player
place_entity enemy

while $PLAYING; do
    clear
    display_dungeon

    read -n 1 -p "Move (w/a/s/d/q): " move
    echo
    move_player $move
done

echo "Game Over!"
echo "Level Reached: $player_level"
echo "Monsters Defeated: $kills"
echo "Gold Accumulated: $player_gold"