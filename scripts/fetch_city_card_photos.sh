#!/usr/bin/env bash
# Downloads real city skyline photos into iOS asset catalog imagesets.
exec python3 "$(dirname "$0")/fetch_city_card_photos.py"
