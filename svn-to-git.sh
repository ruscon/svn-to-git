#!/bin/bash
# To work correctly, you must install the following dependencies
# sudo aptitude install git git-svn

echo -n "Enter the full path to the svn repository: "
read svn_repository

echo "|- Creating a temporary directory for the script"
mkdir -p /tmp/svn-to-git/
cd !$
rm -rf svn git git_fetched_svn_copy bare.git
mkdir svn git

echo "|- Checkout svn repository $svn_repository for generation authors.txt file"
# ЛИБО предвалительно подготовить файл authors.txt, описание в общей статье по миграции и тогда не париться с выкачкой из svn
# OR pre-prepare a file authors.txt, description of common article on migration and did not bathe with the pumping of the svn
cd svn
svn co $svn_repository .
echo "|- Getting a list of all users svn repository"
svn log -q | awk -F '|' '/^r/ {sub("^ ", "", $2); sub(" $", "", $2); print $2" = "$2" <"$2">"}' | sort -u > ../authors.txt
cd ..

echo "|- Running git svn init"
cd git
git svn init $svn_repository --stdlayout --no-metadata
cp ../authors.txt ./
cd ../git
git config svn.authorsfile authors.txt

echo "|- Fetching svn repository files (git svn fetch)"
# На больших репах делается долго
git svn fetch

echo -n "|- Generate .gitignore from trunk ? (y/n): "
read answer
case "$answer" in
[yY])	echo "|-- Generating ..."
	git svn show-ignore -i trunk > .gitignore
	echo '------- cat .gitignore'
	cat .gitignore
	;;
*)	echo "|-- Generation was ignorred";;
esac

# After that, it is best to make a copy of bulging repository if svn work will continue
# Then it will be possible to make only part of the manipulations below, before it again by running git svn fetch
# После этого лучше всего сделать копию выкаченного репозитория, если в svn будет продолжаться работа
# Потом можно будет произвести только часть манипуляций ниже, перед этим снова выполнив команду git svn fetch
echo "|- Doing copy from git folder to git_fetched_svn_copy"
cd ..
cp -R git git_fetched_svn_copy
cd git

echo "|- Creating real tags in the git and removing svn tags migrated from git"
#echo "|- создаём реальные теги в git и удаляем мигрированные svn tags из git"
for t in `git branch -r | grep 'tags/' | sed s_tags/__` ; do
	git tag $t tags/$t^
	git branch -d -r tags/$t
done

echo "|- Deleting trunk, because we have the master"
#echo "|- Удаляем trunk, т.к. он дублирует автоматически созданный master"
git branch -d -r trunk

echo "|- Deleting svn section svn-remote.svn"
#echo "|- Удаляем секцию с svn (у меня почему-то не удалял)"
git config --remove-section svn-remote.svn

echo "|- Writing remote.svn.url"
#echo "|- Указываем в конфиге, что удалённый репозиторий тоже самое что и текущий"
# В статье создаётся как remote.origin.url, но нет смысла это делать
git config remote.svn.url .

echo "|- Writing remote.svn.fetch"
#echo "|- Прописываем куда смотрит удалённый репозиторий"
git config --add remote.svn.fetch +refs/remotes/*:refs/heads/*

echo "|- Run git fetch svn"
#echo "|- Выкачиваем данные / обновляем данные (git fetch svn)"
git fetch svn

echo "|- All current branches and tags"
git branch -a

echo -n "|- Remove all remote branch? (y/n): "
read answer
case "$answer" in
[yY])	git branch -d -r `git branch -a | grep 'remotes/' | sed 's!remotes/!!'`
	echo "|-- Was deleted"
	echo "|-- The remaining branches are:"
	git branch -a
	;;
*)	echo "|-- Removing was ignorred";;
esac

echo "|- Creating bare repository (read man git --bare)"
#echo "|- Создаём bare репозиторий (читайте ман по git --bare)"

echo "|- This is the repository from which you can then make a clone (git clone bare.git)"
#echo "|- Это репозиторий, с которого потом можно делать клон (git clone bare.git)"
cd ..
git clone --bare git bare.git

echo -n "|- Do you want to push the local master to some remote git repository? (y/n): "
read answer
case "$answer" in
[yY])	echo -n "|-- Enter the full path to remote git repository: "
	read remote_git_repository
	cd git
	git remote add origin $remote_git_repository
	git push -u origin master
	;;
*)	echo "|-- Was ignorred";;
esac

echo "|- Done!"
exit 0