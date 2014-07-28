#!/bin/bash -ex

# Grab details about changes from database
# QQQ Should remove this id_Ceej stuff somehow...
ssh -p 29418 -i id_Ceej Ceej@review.couchbase.org gerrit gsql --format pretty -c \""select c.change_id, p.revision, c.dest_project_name, c.dest_branch_name, a.full_name from changes c, patch_sets p, accounts a where c.last_updated_on > '2013-04-01' and c.status='M' and c.change_id=p.change_id and p.patch_set_id=c.current_patch_set_id and c.owner_account_id=a.account_id"\" | tail -n +3 | sed -e 's/ *| */|/g' | sed -e 's/^ *//' > output.txt

echo '<h1>Merges newly missing today:</h1>' > new_missing_merges.html
touch known_problems.txt
failed=0

# Make output directory if necesssary
if [ ! -e repos ]
then
    mkdir repos
    cd repos
else

    # Update any repos that have been previously downloaded
    cd repos
    for repo in *
    do
        (
            echo "Updating local $repo repo..."
            cd $repo
            git fetch
            git reset --hard origin/master
        )
    done
fi

# Read lines of changes
while IFS='|' read -a vals
do
    if [ ! -z "${vals[1]}" ]
    then
        change=${vals[0]}
        sha=${vals[1]}
        project=${vals[2]}
        branch=${vals[3]}
        owner=${vals[4]}

        echo "Checking change $change in project $project ..."

        # Clone or update Gerrit repo for project
        if [ ! -e "$project" ]
        then
            git clone ssh://review.couchbase.org:29418/$project
        fi

        # See if commit's SHA1 is in log
        git --git-dir="$project/.git" log -1 $sha > /dev/null
        if [ $? != 0 ]
        then
            # See if we already know about this problem
            grep -q "$change" ../known_problems.txt
            if [ $? != 0 ]
            then
                echo "<b>$owner</b>: <a href=\"http://review.couchbase.org/#/c/$change/\">change $change</a> -- <i>$project</i> is missing $sha !<br>" | tee --append ../missing_merges.html | tee --append ../new_missing_merges.html
                echo "$change" >> ../known_problems.txt
                failed=1
            fi
        fi

    fi
done < ../output.txt

exit $failed
