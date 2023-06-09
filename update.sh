#!/bin/bash

REPO_NAME='rm-extra'
archs=('x86_64' 'i686' 'pentium4' 'armv7h' 'aarch64' 'any')

is_architecture() {
	for arch in "${archs[@]}"; do
		if [[ "$1" == "$arch" ]]; then
			echo true
		fi
	done
}

for arch in "${archs[@]}"; do
	if [[ ! -d "$arch" ]]; then
		mkdir ./"$arch"
	else
		cd ./"$arch"
		echo Removing all archives and database files from "$arch"...
		rm ./*.tar.gz ./*.tar.gz.old ./*.db ./*.files > /dev/null 2>&1
		cd ..
	fi
done

for dir in *; do
	is_arch=$(is_architecture "$dir")
	if [[ ! "$is_arch" ]]; then

		# Skip if not a directory
		if [[ ! -d ./"$dir" ]]; then
			continue
		fi

		# Does this package have no updates available?
		# If not, skip it
		if [[ "$(updpkgver ./"$dir" --dont-update)" != *'Update available for'* ]]; then
			# If there are no database files in the directory, then an update is mandatory
			if ls ${dir}/*.pkg.tar.zst 1> /dev/null 2>&1; then
				echo "No updates available for ${dir}, skipping"
				continue
			fi
		fi

		cd ./"$dir"

		# Convert the package's compatible architectures
		# into an array
		pkg_archs=( $(awk -F "'" '
			/^arch=/ {
				for (i=2; i<NF; i+=2) {
					print $i
				}
			}
			' ./PKGBUILD) )
		
		# Remove all outdated packages
		echo Removing all packages from "$dir"
		rm ./*.pkg.tar.zst > /dev/null 2>&1

		if [[ ! -f './.SRCINFO' ]]; then
			echo Creating \'./.SRCINFO\'
			makepkg --printsrcinfo > './.SRCINFO'
		fi

		echo Updating package version...
		updpkgver .
		echo Updating package checksums...
		updpkgsums

		echo Updating \'./.SRCINFO\'
		makepkg --printsrcinfo > './SRCINFO'
		echo Executing makepkg for "$dir"
		makepkg -f || exit

		for pkg_arch in "${pkg_archs[@]}"; do
			# Is this an unknown architecture?
			if [[ ! -d "../$pkg_arch" ]]; then
				echo Unknown architecture for "$dir": "$pkg_arch"
				exit
			fi
			cp ./*"$pkg_arch".pkg.tar.zst ../"$pkg_arch"
		done

		cd ..
	fi
done

echo Successfully finished building packages...
echo Setting up repositories...

for arch in "${archs[@]}"; do
	cd ./"$arch" || exit

	if [[ -z "$(ls ./)" ]]; then
		echo No files found in "$arch"... Skipping
		cd ..
		continue
	fi

	# Add the database files..
	repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
	rm ./"$REPO_NAME".db ./"$REPO_NAME".files
	mv ./"$REPO_NAME".db.tar.gz ./"$REPO_NAME".db
	mv ./"$REPO_NAME".files.tar.gz ./"$REPO_NAME".files
	cd ..
done

git config user.name 'Bot'
git config user.email 'bot@bot.com'
git add .
git commit -m 'Autoupdate'
git push origin master
