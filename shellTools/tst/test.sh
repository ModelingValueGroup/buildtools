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
##     Wim Bast, Carel Bast, Tom Brus                                                                                  ~
## Contributors:                                                                                                       ~
##     Arjan Kok, Ronald Krijgsheld                                                                                    ~
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set -euo pipefail

if [[ "${GITHUB_WORKSPACE:-}" == "" ]]; then
  export GITHUB_WORKSPACE="$PWD"
  export GITHUB_REPOSITORY="ModelingValueGroup/buildTools"

  ##### mimic github actions env for local execution:
  . ~/secrets.sh # defines INPUT_TOKEN without exposing it in the github repos
  if [[ "${INPUT_TOKEN:-}" == "" ]]; then
    echo ":error:: local test runs require a file ~/sercrets.sh that defines at least INPUT_TOKEN"
    exit 67
  fi

  if [[ "$(command -v md5)" != "" && "$(command -v md5sum)" == "" ]]; then
    md5sum() { md5; }
  fi
  xmlstarlet() {
    :
  }
fi

##### make tmp dir
tmp=./tmp
rm -rf $tmp
mkdir $tmp
cd $tmp

[[ -f ../buildTools.jar               ]] && cp ../buildTools.jar .               || :
[[ -f ../out/artifacts/buildTools.jar ]] && cp ../out/artifacts/buildTools.jar . || :
set -x
find .. -type f
. <(java -jar ./buildTools.jar)

##### tests ###########################################################################################################
test_00() {
  fromjar() {
    java -jar ./buildTools.jar
  }
  fromdir() {
    echo "#!/usr/bin/env bash"
    for sh in ../shellTools/res/*.sh; do
      echo "###@@@ $(basename "$sh")"
      sed '/^#!\/usr\/bin\/env bash$/d' "$sh"
    done
  }

  if [[ "$(fromjar)" != "$(fromdir)" ]]; then
    echo "::error::test failed: jar does not correctly deliver scripts"
    diff <(printf "%s" "$(fromjar)") <(printf "%s" "$(fromdir)")
    exit 46
  else
    echo "test OK: jar does correctly deliver scripts"
  fi
}
#######################################################################################################################
test_01() {
  downloadArtifactQuick "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "."
  local sum="$(md5sum < buildTools.sh | sed 's/ .*//')"
  local exp="da493bbcf960af426c47a51f876395d0"
  if [[ "$sum" != "$exp" ]]; then
    echo "::error::downloadArtifactQuick failed (md5sum unexpected: $sum and $exp expected)"
    exit 65
  fi
  rm buildTools.sh
  echo "test OK: downloadArtifactQuick is working correctly"
}
#######################################################################################################################
test_02() {
  downloadArtifact "$INPUT_TOKEN" "com.modelingvalue" "buildTools" "1.0.4" "sh" "."
  local sum="$(md5sum < buildTools.sh | sed 's/ .*//')"
  local exp="da493bbcf960af426c47a51f876395d0"
  if [[ "$sum" != "$exp" ]]; then
    echo "::error::downloadArtifact failed (md5sum unexpected: $sum and $exp expected)"
    exit 65
  fi
  rm buildTools.sh
  echo "test OK: downloadArtifact is working correctly"
}
#######################################################################################################################
test_03() {
  printf "aap\r\nnoot\r\n" > testfile_crlf.txt
  printf "aap\nnoot\n"     > testfile_lf.txt
  if cmp -s testfile_crlf.txt testfile_lf.txt; then
    echo "::error::correctEols failed (precheck)"
    exit 67
  fi
  correctEols
  if ! cmp -s testfile_crlf.txt testfile_lf.txt; then
    echo "::error::correctEols failed"
    exit 67
  fi
  rm testfile_crlf.txt testfile_lf.txt
  echo "test OK: correctEols is working correctly"
}
#######################################################################################################################
test_04() {
  printf "xxx" > hdr
  printf "aap\nnoot\n" > testfile.java
  printf "//~~~~~~\n// xxx ~\n//~~~~~~\n\naap\nnoot\n" > testfileref.java
  correctHeaders hdr
  if ! cmp -s testfile.java testfileref.java; then
    echo "::error::correctHeaders failed"
    exit 67
  fi
  rm hdr testfile.java testfileref.java
  echo "test OK: correctEols is working correctly"
}
#######################################################################################################################

##### test execution:
group test_00
group test_01
group test_02
group test_03
group test_04

##### ok if we end up here
echo "all tests OK"
