To create new local git repo (from a terminal in the folder)

git init

To add all files in the folder to the repo

git add .

To commit all files added

git commit -m "some msg"

To Add repo to Github
Create a new repo in git hub and copy the .git url

git remote add origin ".git URL from github"
git push --set-upstream origin master
git pull origin master --allow-unrelated-histories
git push
