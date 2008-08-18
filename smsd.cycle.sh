#!/bin/sh
while true; do
    date
    ./smsd.rb

    sleep 5
    
    echo -n "Finished at "
    date
done
