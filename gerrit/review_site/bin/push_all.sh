#!/bin/sh

rp=$HOME/review_site

push() {
    project=`basename $1 .git`

    case $project in
	membase)
	    repo="git@github.com:northscale/ep-engine.git"
	    ;;
	spymemcached)
	    repo="git@github.com:dustin/java-memcached-client.git"
	    ;;
	*)
	    repo="git@github.com:northscale/$project.git"
	    ;;
    esac

    echo "Pushing $project to $repo"

    cd $rp/git/$1
    git push $repo
}

cd $rp/git
for i in *
do
    push $i
done
