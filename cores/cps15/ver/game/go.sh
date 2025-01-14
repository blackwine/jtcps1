#!/bin/bash

GAME=punisher
PATCH=
OTHER=
GOOD=0

while [ $# -gt 0 ]; do
    case $1 in
        -g|-game)  shift; GAME=$1;;
        -p|-patch) shift; PATCH=$1;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

for i in wof wofa wofj wofu dino dinoa dinohunt dinoj dinou punisher punisherbz punisherh punisherj punisheru mbomberj slammast slammastu mbombrd mbombrdj; do
    if [ $GAME = $i ]; then
        GOOD=1
        break
    fi
done

if [ $GOOD = 0 ]; then
    echo "The specified game is not a CPS 1.5 title"
    exit 1
fi

# Prepare ROM file and config file
make || exit $?
ln -sf $ROM/$GAME.rom rom.bin
rom2hex rom.bin || exit $?

CFG_FILE=cps_cfg.hex
if [[ ! -e $CFG_FILE ]]; then
    echo "ERROR: could not find the required snapshot files"
    ls $CFG_FILE
    exit 1
fi

CPSB_CONFIG=$(cat $CFG_FILE)

export MEM_CHECK_TIME=310_000_000
# 280ms to load the ROM ~17 frames
export CONVERT_OPTIONS="-resize 300%x300%"

# Generic simulation script from JTFRAME
$JTFRAME/bin/sim.sh -mist \
    -sysname cps15 \
    -def ../../hdl/jtcps15.def \
    -d CPSB_CONFIG="$CPSB_CONFIG"  \
    -d JT9346_SIMULATION -d JTDSP16_FWLOAD -d SKIP_RAMCLR \
    -videow 384 -videoh 224 \
    $OTHER
# -d JTCPS_TURBO