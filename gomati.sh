#!/bin/bash

# Google Maps Tile Downloader & Stitcher
# https://github.com/doersino/gomati
# MIT License
#
# Usage: Adjust config below, run gomati.sh [-v | -q] (it stands for GOogle MAps
# TIles and is apparently also a river??, which sorta fits the theme).
#
# Requirements: - bash (duh)
#               - bc (for various calculations)
#               - awk (doesn't need to be GNU awk; for random number generation)
#               - curl (for downloading tiles)
#               - imagemagick (for stitching 'em together)
#
# Note 1: The LATITUDE and LONGITUDE variables can be figured out by opening
# Google Maps in a browser, navigating to the area of interest and dropping a
# pin or taking a peek at the URL. It should look as follows (if Greenwich
# observatory is at the center of the map, that is):
# https://www.google.com/maps/@51.4768469,-0.000565,62m/data=!3m1!1e3
#                              ---------- ---------
#                              LATITUDE   LONGITUDE
#                              in °       in °
#
# Note 2: The ZOOM variable relates to the way map tiles are subdivided when
# zooming in – for Zoom level 0, there exists a single 256x256px tile that shows
# the entire world. Zoom level 1 subdivides this tile into four quadrants which
# are again 256x256px large and thus of a higher resolution. Further zoom levels
# subdivide the previous zoom level's tiles analogously. Note that a tile covers
# a square area that's ~40000000/2^ZOOM meters on each side (the earth's
# circumference is roughly 40,000,000 meters). As a result, I find zoom factors
# 10 (where tiles cover ~40 km) to 16 (~600 m) to be most useful. For details,
# see: https://developers.google.com/maps/documentation/javascript/coordinates
#
# Note 3: If WIDTH and HEIGHT are both set to 1, the script will download the
# map tile at the configured ZOOM level that contains the configured coordinate
# pair. Otherwise, WIDTH horizontal (longitudinal) and HEIGHT vertical
# (latitudinal) tiles centered around that tile will be downloaded and stitched
# together into an image (meaning that increasing WIDTH and HEIGHT zooms the
# view out even if you keep ZOOM constant). Note that your coordinate pair is
# not necessarily smack in the middle of the result image since it might lie
# towards one corner of the central tile – this shortcoming is a compromise
# between 1. requiring you to specify tile coordinates (instead of lat/lon) at
# the selected zoom level or 2. letting this script spiral into a full-fledged
# mapping engine (I pen-and-paper developed into this direction, but didn't feel
# like spending the time implementing and debugging it, especially not in bash).
#
# Note 5: You can supply ranges for LATITUDE and LONGITUDE, e.g. 40_50 (the
# separator is "_" and not "-" as this would clash with negative latitudes and
# longitudes). A random real number from this range is then selected. In
# combination with "while true; do bash gomati.sh; done", this can be used to
# create a virtually endless number of maps of random places.
# Similarly, if you set "ZOOM=$1", you can generate a series of successively-
# higher-zoom images via `for i in $(seq 0 20); do bash gomati.sh $i; done`.
#
# Note 5: The CONFIG variable can be used for a more compact notation of the
# configuration parameters. It must be set to a bash array, i.e. it must take
# the form "CONFIG=(LATITUDE LONGITUDE ZOOM WIDTH HEIGHT). If set, it takes
# precedence over the previously introduced variables. Also, environment
# variables GOMATI_LATITUDE, GOMATI_LONGITUDE, GOMATI_ZOOM, GOMATI_WIDTH,
# GOMATI_HEIGHT, GOMATI_PRETTIFY, GOMATI_CROP, GOMATI_RESIZE, and GOMATI_OUTFILE
# override, if they are set, whatever values are configured in this file – e.g.
# "GOMATI_ZOOM=10 bash gomati.sh" overrides the zoom level but leaves the other
# variables as they are defined in the source.
#
# Note 7: Green cells of the progress indicator imply a successfully downloaded
# tile, blue cells indicate a previously-downloaded tile, light red ones
# indicate a 404 error (which can occur if your configured zoom level exceeds
# what's available for the region), red ones indicate a general error (pass the
# -v flag to find out more) and gray ones are yet to be downloaded.
#
# Fun fact: Building the progress indiciator was the most complicated part of
# this work, and I'm sure it's not elegantly done at all. I almost rewrote this
# script in Python to have an easier time with that!
#
# Examples: | LAT    | LON     | ZOOM | WIDTH | HEIGHT | Description           |
#           | ------ | ------- | ---- | ----- | ------ | ----------------------|
#           | 48.52  | 9.06    | 13   | 5     | 5      | Tübingen, Germany     |
#           | 40.755 | -73.985 | 15   | 5     | 5      | Midtown Manhattan, NY |
#           | 36.27  | 127.52  | 10   | 16    | 22     | South Korea           |
#           | 37.471 | 126.703 | 17   | 25    | 25     | Sipjeong-dong, Korea  |
#           | 37.772 | 128.891 | 16   | 25    | 25     | Gangneung, Korea      |
#
# The first example could alternatively be written as "CONFIG=(48.52 9.06 13 5
# 5)". An example range (covers most of South Korea): "CONFIG=(37.7_35.1
# 126.3_129.3 15 5 5)".

##########
# CONFIG #
##########

LATITUDE=48.52  # ⎤ latitude and longitude of central tile of desired map
LONGITUDE=9.06  # ⎦ in °

ZOOM=13  # tile zoom level (0-20, larger level -> things look bigger)

WIDTH=5   # ⎤ dimensions of desired map
HEIGHT=5  # ⎦ in tiles

# shorthand examples
#CONFIG=(48.52 9.06 13 5 5)                   # tübingen
#CONFIG=(37.7_35.1 126.3_129.3 15 5 5)        # random location in south korea
#CONFIG=(47.97_29.97 -106.44_-90.93 14 5 5)   # random location in the american
                                              # heartland, about 6 by 6 miles
#CONFIG=(47.97_29.97 -106.44_-90.93 15 7 7)   # same, about 4 miles, higher-res
#CONFIG=(47.97_29.97 -106.44_-90.93 17 7 7)   # same, about 1 mile (tweets at
                                              # @americasquared)
#CONFIG=(48.51847 9.05814 18 80 80)           # massive map of tübingen (420M
                                              # pxiels, imagemagick eats ~12G of
                                              # RAM during stitching, so be
                                              # careful)

PRETTIFY=true  # increase brightness, contrast and saturation a notch?
CROP=false     # e.g. CROP=1000x1000 extracts the middle 1000x1000 pxiles of the
               # image – this is handy when you want the result image to show
               # an area that's not a multiple of the tile size at the selected
               # zoom level (note that cropping is performed before resizing)
RESIZE=false   # e.g. RESIZE=1360x1360 resizes (without padding or distortion)
               # the result to stretch or fit into a 1360x1360 pixel rectangle,
               # while RESIZE=false disables resizing (note that resizing is
               # performed after cropping)

#OUTFILE="out.jpg"  # if set, this overrides the auto-generated output filename

################################################################################

TIME_START=$(date +%s)

VERBOSE=false
QUIET=false
if [ "$1" = "-v" ]; then
    VERBOSE=true
elif [ "$1" = "-q" ]; then
    QUIET=true
fi

function status {
    $QUIET && return

    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    echo "${BOLD}$@${NORMAL}"
}

P_ALREADY_DOWNLOADED=1
P_JUST_DOWNLOADED=2
P_ERROR=3
P_ERROR_NOT_FOUND=4
P_NEWLINE=5
P_BAR=""
P_COUNT=0
function p_reset {
    P_BAR=""
    echo  # newline
}
function p_print {
    GRAY=$(tput setaf 7)
    GREEN=$(tput setaf 2)
    BLUE=$(tput setaf 4)
    RED=$(tput setaf 1)
    NORMAL=$(tput sgr0)

    P_TMP="$(printf %-${WIDTH}s "${P_BAR}" | tr " " "B")"
    P_TMP="${P_TMP//B/${GRAY}░${NORMAL}}"
    P_TMP="${P_TMP//X/${GREEN}█${NORMAL}}"
    P_TMP="${P_TMP//H/${BLUE}█${NORMAL}}"
    P_TMP="${P_TMP//E/${RED}█${NORMAL}}"
    P_TMP="${P_TMP//N/${RED}▓${NORMAL}}"

    P_TOTAL=$((WIDTH*HEIGHT))
    P_PERCENT="$(LC_NUMERIC=C printf '%5.2f' $(echo "100*$P_COUNT/$P_TOTAL" | bc -l))"
    P_NUMBERS="$P_PERCENT%% ($P_COUNT/$P_TOTAL)"
    if [ -z "$1" ]; then
        printf "$P_TMP $P_NUMBERS\r"
    else
        printf "$P_TMP"

        # if first arg set, print spaces instead of percentage in order to
        # overwrite a previously printed percentage
        printf %-${#P_NUMBERS}s " "
        printf "\r"
    fi
}
function p_add {
    P_COUNT=$((P_COUNT+1))
    P_BAR="${P_BAR}$1"
}
function progress {
    $QUIET && return

    case $1 in
        $P_ALREADY_DOWNLOADED)
            p_add "H"
            p_print
            ;;
        $P_JUST_DOWNLOADED)
            p_add "X"
            p_print
            ;;
        $P_ERROR)
            p_add "E"
            p_print
            ;;
        $P_ERROR_NOT_FOUND)
            p_add "N"
            p_print
            ;;
        $P_NEWLINE)
            p_print thrust
            p_reset
            ;;
    esac
}

function random_real_from_range {
    RANGE="$1"

    # split range on _
    IFS='_' read -ra RANGEARR <<< "$RANGE"

    # read lower and upper bound into variables (order actually doesn't matter
    # because of the math further down, which is very convenient)
    LOWER="${RANGEARR[0]}"
    UPPER="${RANGEARR[1]}"

    # generate random number (seed=$RANDOM$RANDOM$RANDOM since $RANDOM returns
    # an integer in the range 0..32759 and we might want to be able to generate
    # more than 32760 distinct random numbers)
    awk -v "seed=$RANDOM$RANDOM$RANDOM" -v "l=$LOWER" -v "u=$UPPER" \
        'BEGIN { srand(seed); printf("%.5f\n", l + rand() * (u - l)) }'
}

################################################################################

# decompose CONFIG variable if set
if [ ! -z "$CONFIG" ]; then
    LATITUDE="${CONFIG[0]}"
    LONGITUDE="${CONFIG[1]}"
    ZOOM="${CONFIG[2]}"
    WIDTH="${CONFIG[3]}"
    HEIGHT="${CONFIG[4]}"
fi

# take data from environment variables if set
[ ! -z "$GOMATI_LATITUDE" ]  && LATITUDE="$GOMATI_LATITUDE"
[ ! -z "$GOMATI_LONGITUDE" ] && LONGITUDE="$GOMATI_LONGITUDE"
[ ! -z "$GOMATI_ZOOM" ]      && ZOOM="$GOMATI_ZOOM"
[ ! -z "$GOMATI_WIDTH" ]     && WIDTH="$GOMATI_WIDTH"
[ ! -z "$GOMATI_HEIGHT" ]    && HEIGHT="$GOMATI_HEIGHT"
[ ! -z "$GOMATI_PRETTIFY" ]  && PRETTIFY="$GOMATI_PRETTIFY"
[ ! -z "$GOMATI_CROP" ]      && CROP="$GOMATI_CROP"
[ ! -z "$GOMATI_RESIZE" ]    && RESIZE="$GOMATI_RESIZE"
[ ! -z "$GOMATI_OUTFILE" ]   && OUTFILE="$GOMATI_OUTFILE"

# handle ranges
if [[ ! "$LATITUDE" =~ ^-?[0-9.]+$ ]]; then
    LATITUDE="$(random_real_from_range "$LATITUDE")"
fi
if [[ ! "$LONGITUDE" =~ ^-?[0-9.]+$ ]]; then
    LONGITUDE="$(random_real_from_range "$LONGITUDE")"
fi

# compute tile corresponding to LAITUDE and LONGITUDE at selected ZOOM level by
# applying the web mercator projection formulas, see
# https://en.wikipedia.org/wiki/Web_Mercator_projection
PI="3.14159265358979"
FACTOR="(256/(2*$PI))*(2^($ZOOM-8))"
XFORMULA="$FACTOR*(($LONGITUDE*($PI/180))+$PI)"
TANARG="(($PI/4)+(($LATITUDE*($PI/180))/2))"
YFORMULA="$FACTOR*($PI-l(s($TANARG)/c($TANARG)))"

XMID=$(echo "x = $XFORMULA; scale = 0; x / 1" | bc -l | xargs printf "%.0f\n")
YMID=$(echo "y = $YFORMULA; scale = 0; y / 1" | bc -l | xargs printf "%.0f\n")

# compute start and end tiles
XSTART=$(echo "x = $XMID-($WIDTH/2)+1; scale = 0; x / 1" | bc -l)
YSTART=$(echo "y = $YMID-($HEIGHT/2)+1; scale = 0; y / 1" | bc -l)
XEND=$(echo "x = $XMID+($WIDTH/2); scale = 0; x / 1" | bc -l)
YEND=$(echo "y = $YMID+($HEIGHT/2); scale = 0; y / 1" | bc -l)

# set output paths
TILEDIR="./gomati-tiles"
if [ -z "$OUTFILE" ]; then
    OUTFILE="gomati-lat${LATITUDE}lon${LONGITUDE}-zoom${ZOOM}x${XSTART}+${WIDTH}y${YSTART}+${HEIGHT}.jpg"
fi

# pick mirror
MIRROR=$((RANDOM % 4))

# faux user agent (google throws an error if it detects that we're using curl)
UA="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:59.0) Gecko/20100101 Firefox/59"

# output of configuration for sanity check purposes
$VERBOSE && cat << EOF
LATITUDE $LATITUDE
LONGITUDE $LONGITUDE
ZOOM $ZOOM
WIDTH $WIDTH
HEIGHT $HEIGHT
=>
XSTART $XSTART
YSTART $YSTART
XMID $XMID
YMID $YMID
XEND $XEND
YEND $YEND
EOF

################################################################################

status "Downloading map tiles..."

# prepare file system
mkdir -p "$TILEDIR"
cd "$TILEDIR"

# list of "done" files – the order is important (ordered by y (column) first, x
# (row) last), it'll later be used for stitching)
FILES=""

# note the if these loops are reversed, the result ends up transposed and
# glitchy-looking
for Y in $(seq $YSTART $YEND); do
    for X in $(seq $XSTART $XEND); do

        FILENAME="zoom${ZOOM}x${X}y${Y}.jpg"

        # avoid downloading a file we already have again
        if [ -f "$FILENAME" ]; then
            $VERBOSE && echo "$FILENAME already downloaded"
            progress $P_ALREADY_DOWNLOADED
        else
            curl                       \
              $($VERBOSE || echo "-s") \
              -f                       \
              --user-agent "$UA"       \
              -o "$FILENAME"           \
              "https://khms${MIRROR}.google.com/kh/v=865?x=${X}&y=${Y}&z=${ZOOM}"

            RETURN=$?
            if [ $RETURN -eq 0 ]; then
                progress $P_JUST_DOWNLOADED
            elif [ $RETURN -eq 22 ]; then
                progress $P_ERROR_NOT_FOUND
            else
                progress $P_ERROR
            fi
        fi

        # append to "done" list
        FILES="$FILES $FILENAME"

        # preserve progress info if verbose output selected
        $VERBOSE && echo
    done

    progress $P_NEWLINE
done

################################################################################

status "Stitching 'em together..."
montage                          \
  $($VERBOSE && echo "-monitor") \
  -mode concatenate              \
  -tile ${WIDTH}x${HEIGHT}       \
   $FILES                        \
   "$OUTFILE"

# if an error has occurred during downloading or stitching (the rest of the
# pipeline is unlikely to yield an error), the previous command will have
# returned a nonzero exit code, which we'll store and return at the end of this
# script to indicate failure
EXIT=$?

if $PRETTIFY; then
    status "Adjusting brightness, contrast and saturation..."
    mogrify                          \
      $($VERBOSE && echo "-monitor") \
      -brightness-contrast +3,+6     \
      -modulate 100,107              \
      "$OUTFILE"
fi

if [ ! $CROP = false ]; then
    status "Cropping the central $CROP pixels from image..."
    mogrify                          \
      $($VERBOSE && echo "-monitor") \
      -gravity Center                \
      -crop ${CROP}+0+0              \
      +repage                        \
      "$OUTFILE"
fi

if [ ! $RESIZE = false ]; then
    status "Resizing image to a maximum of $RESIZE pixels..."
    mogrify                          \
      $($VERBOSE && echo "-monitor") \
      -resize $RESIZE                \
      "$OUTFILE"
fi

################################################################################

cd - >/dev/null
cp "$TILEDIR/$OUTFILE" .
rm "$TILEDIR/$OUTFILE"

TIME_END=$(date +%s)
TIME_TOTAL=$((TIME_END-TIME_START))

status "Done after $TIME_TOTAL seconds."

exit $EXIT
