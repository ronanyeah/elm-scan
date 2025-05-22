while true
do
    inotifywait -e modify -q -r ./src --include "\.elm$"
    elm make --output=/dev/null src/ReviewConfig.elm
done
