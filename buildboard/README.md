How to start Buildboard:

1. Run the start-buildboard.sh script under the "docker" folder.  The script will create 2 separate docker containers: build-couchbase-server and buildboard.  These 2 containers are linked to allow communication between them on the same host machine.
2. Delete the following html files in the folder "html".
    - Sherlock.html
    - Watson.html 
3. Go in the "buildboard" container and run the following command under the "buildboard" folder.
    ./buildboard.py > buildboard_err.log 2>&1 &
