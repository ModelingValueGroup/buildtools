#!/usr/bin/env bash
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## (C) Copyright 2018-2019 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
##                                                                                                                     ~
## Licensed under the GNU Lesser General Public License v3.0 (the 'License'). You may not use this file except in      ~
## compliance with the License. You may obtain a copy of the License at: https://choosealicense.com/licenses/lgpl-3.0  ~
## Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on ~
## an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the  ~
## specific language governing permissions and limitations under the License.                                          ~
##                                                                                                                     ~
## Maintainers:                                                                                                        ~
##     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Carel Bast                                                                                           ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

pushBackToGithub() {
    local token="$1"; shift
    local email="$1"; shift
    local   msg="$1"; shift

    git ls-files --deleted --modified --others --exclude-standard || :
    if [[ "$(git ls-files --deleted --modified --others --exclude-standard)" ]]; then
        echo "changes need to be pushed back to github"

        echo "::group::git commit and push" 1>&2
            git config user.email "$email"
            git config user.name "$GITHUB_ACTOR"
            git add .
            git commit -m "$msg"
            git push "$(getGithubRepoSecureUrl "$token" "$GITHUB_REPOSITORY")"
        echo "::endgroup::" 1>&2

    else
        echo "no changes need to be pushed back to github"
    fi
}
errorIfVersionTagExists() {
    . <(catProjectSh 'local ')
    local tagName="v$version"
    if [[ "$(git tag | fgrep -Fx "$tagName")" == "" ]]; then
        echo "ok: no such tag ($tagName)"
    else
        echo "existing tags:"
        git tag | sed 's/^/=== /'
        echo "::error::tag for this version ($tagName) already set, can not build on master"
        exit 89
    fi
}
setVersionTag() {
    local token="$1"; shift
    local email="$1"; shift

    . <(catProjectSh 'local ')
    # shellcheck disable=SC2154
    local tagName="v$version"
    if [[ "$(git tag | fgrep -Fx "$tagName")" == "" ]]; then
        echo "setting tag $tagName"
        git config user.email "$email"
        git config user.name  "$GITHUB_ACTOR"
        git tag "$tagName"
        git push "$(getGithubRepoSecureUrl "$token" "$GITHUB_REPOSITORY")" "$tagName"
    else
        echo "::error::tag for this version ($tagName) already exists"
        exit 88
    fi
}
getLatestAsset() {
    local    owner="$1"; shift
    local repoName="$1"; shift
    local     file="$1"; shift

    curl \
        --location \
        --remote-header-name \
        --remote-name \
        --fail \
        --silent \
        --show-error \
        "https://github.com/$owner/$repoName/releases/latest/download/$file"
}
getAllLatestAssets() {
    local    token="$1"; shift
    local    owner="$1"; shift
    local repoName="$1"; shift

    local query='
            {
              repository(owner: "'"$owner"'", name: "'"$repoName"'") {
                releases(last: 1) {
                  nodes {
                    releaseAssets(first:100){
                      nodes{
                        downloadUrl
                      }
                    }
                  }
                }
              }
            }
        '
    local select='.data.repository.releases.nodes[].releaseAssets.nodes[].downloadUrl'

    for u in $(graphqlQuery "$token" "$query" "$select"); do
        echo "downloading $u..." 1>&2
        curlSave "$token" "$u"
    done
}
setOutput() {
    local  name="$1"; shift
    if [[ "$#" == 0 ]]; then
        local value="$(cat)"
    else
        local value="$1"
    fi

    value="${value//'%'/'%25'}"
    value="${value//'\n'/'%0A'}"
    value="${value//'\r'/'%0D'}"

    echo "::set-output name=$name::$value"
}






#deprecated: use 'if' of step in yaml
errorIfMasterAndVersionTagExists() {
    if [[ "${GITHUB_REF##*/}" != master ]]; then
        echo "ok: not on master"
    else
        errorIfVersionTagExists
    fi
}
#deprecated: use 'if' of step in yaml
setVersionTagIfMaster() {
    local token="$1"; shift
    local email="$1"; shift

    if [[ "${GITHUB_REF##*/}" != master ]]; then
        echo "ok: not on master"
    else
       setVersionTag "$token" "$email"
    fi
}
