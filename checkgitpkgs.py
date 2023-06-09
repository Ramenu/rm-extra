#!/bin/python

import urllib.request
import json
import subprocess
from os.path import basename
from datetime import datetime
from sys import argv

# For converting datetime formats
GITHUB_TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ'

PKGS_REPO_NAME = 'rm-extra'
PKGS_REPO = f'https://api.github.com/repos/Ramenu/{PKGS_REPO_NAME}'

# URL to the files and folders of the repository
PKGS_REPO_CONTENTS = f'{PKGS_REPO}/contents/'

# CPU architectures
ARCHS = ['x86_64', 'i686', 'pentium4', 'armv7h', 'aarch64', 'any']


def pkgNeedsUpdate(pkgName : str, rm_extra_pushed_at : str) -> bool:
    try:
        repoUrl = f'https://api.github.com/repos/Ramenu/{pkgName}'
        repo = json.load(urllib.request.urlopen(repoUrl))

        repo_pushed_at = datetime.strptime(repo['pushed_at'], GITHUB_TIME_FORMAT)

        return repo_pushed_at > rm_extra_pushed_at
    except urllib.error.HTTPError as err:
        print(f'HTTPError: {err.code}')
        exit(1)
    except urllib.error.URLError as err:
        print(f'URLError: {err.reason}')
        exit(1)

if __name__ == '__main__':
    try:
        # Check when the 'rm_extra' was last pushed to and format the date 
        # and time into something the datetime module can understand
        rm_extra_pushed_at = json.load(urllib.request.urlopen(PKGS_REPO))['pushed_at']
        rm_extra_pushed_at = datetime.strptime(rm_extra_pushed_at, GITHUB_TIME_FORMAT)

        # Check if there is an argument passed to 'checkpkgs', if so we only check if
        # the package provided as an argument needs an update only, rather than checking
        # the entire directory
        if len(argv) >= 2:
            # we assume that second argument is the name of the package
            pkgName = argv[1]
            if pkgNeedsUpdate(pkgName, rm_extra_pushed_at):
                print(f'{pkgName} requires an update')
            exit(0)

        # Fetch the git repository of 'rm-extra' and go through the directory's contents
        # one by one to see if any of the packages requires an update
        with urllib.request.urlopen(PKGS_REPO_CONTENTS) as res:
            if res.status == 200:
                pkgs = json.load(res)

                # Check all the files and directories in the repository
                for path in pkgs:
                    pathName = path['name']
                    pathType = path['type']

                    # Skip the path if it's a file or an architecture folder
                    if pathName in ARCHS or pathType == 'file':
                        continue
                    
                    if pkgNeedsUpdate(pathName, rm_extra_pushed_at):
                        print(f'{pathName} requires an update')
            else:
                print(f'request failed with status code: {res.status}')
    except urllib.error.HTTPError as err:
        print(f'HTTPError: {err.code}')
    except urllib.error.URLError as err:
        print(f'URLError: {err.reason}')

