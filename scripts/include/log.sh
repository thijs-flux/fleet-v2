LOG_LEVEL=1

function log() {
    local lvl="${1:?}" msg="${2:?}"
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
    if ((lvl_n>=LOG_LEVEL)); then
        echo "[${lvl^^}]" "$msg"
    fi
    if [[ $lvl == error ]]; then
        echo "exiting..."
        exit -1 
    fi
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