LOG_LEVEL=info

function log() {
    local lvl="${1:?}" msg="${2:?}"
    local lvl_n
    lvl_n=$(get_log_level $lvl)
    if ((lvl_n>=LOG_LEVEL)); then
        echo "[${lvl^^}]" "$msg"
    fi
    if [[ $lvl == error ]]; then
        echo "exiting..."
        exit -1 
    fi
}

function get_log_level() {
    lvl=$1
    local lvl_n
    case "$lvl" in
        "debug")
            lvl_n=0
            ;;
        "info")
            lvl_n=1
            ;;
        "warn")
            lvl_n=2
            ;;
        "error")
            lvl_n=3
            ;;
        *)
            echo Unknown log level "$lvl"
            lvl_n=3
            ;;
    esac
    echo $lvl_n
}

function log_level() {
    lvl=$(get_log_level $LOG_LEVEL)
    echo ${lvl}
}

function set_log_level() {
    while getopts "hdq:" flag; do
    case $flag in
        d) 
        LOG_LEVEL=debug
        ;;
        q) 
        LOG_LEVEL=error
        ;;
    esac
    done
}