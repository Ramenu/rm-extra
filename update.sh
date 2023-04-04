#!/bin/bash

REPO_NAME="rm-extra"
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
		if [[ ! -d ./"$dir" ]]; then
			continue
		fi
		cd ./"$dir"
		pkg_archs=( $(awk -F "'" '
			/^arch=/ {
				for (i=2; i<NF; i+=2) {
					print $i
				}
			}
			' ./PKGBUILD) )
		
		echo Removing all packages from "$dir"
		rm ./*.pkg.tar.zst > /dev/null 2>&1

		echo Executing makepkg for "$dir"
		makepkg -f || exit

		for pkg_arch in "${pkg_archs[@]}"; do
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
	repo-add "$REPO_NAME".db.tar.gz ./*.pkg.tar.zst
	rm ./"$REPO_NAME".db ./"$REPO_NAME".files
	mv ./"$REPO_NAME".db.tar.gz ./"$REPO_NAME".db
	mv ./"$REPO_NAME".files.tar.gz ./"$REPO_NAME".files
	cd ..
done
