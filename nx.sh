#!/usr/bin/env bash
# nx.sh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -ex
ROOTDIR=$(realpath $(dirname $(readlink -f ${0})))
NUTTXDIR=${ROOTDIR}/nuttx
TOOLSDIR=${NUTTXDIR}/tools

bear_version=`bear --version 2>&1 | awk -F '[ .]' '/bear/{print $2}'`
if [ "$bear_version" == "3" ]; then
	BEAR="bear --append --"
else
	BEAR="bear --append "
fi

function build_board()
{
  echo -e "Build command line:"
  echo -e "  ${TOOLSDIR}/configure.sh -e $1"
  echo -e "  make -C ${NUTTXDIR} ${@:2}"
  echo -e "  make -C ${NUTTXDIR} savedefconfig"

  if ! ${TOOLSDIR}/configure.sh -e $1; then
    make -C ${NUTTXDIR} distclean -j4
    rm $ROOTDIR/compile_commands.json
    if ! ${TOOLSDIR}/configure.sh $1; then
      echo "Error: ############# config ${1} fail ##############"
      exit 1
    fi
  fi

  if ! ${BEAR} make -C ${NUTTXDIR} ${@:2} ; then
    echo "Error: ############# build ${1} fail ##############"
    exit 2
  fi

  if [ "${2}" == "distclean" ]; then
    rm -rf $ROOTDIR/compile_commands.json
    return;
  fi

  make -C ${NUTTXDIR} savedefconfig
  if [ ! -d $1 ]; then
    cp ${NUTTXDIR}/defconfig ${ROOTDIR}/nuttx/boards/*/*/${1/[:|\/]//configs/}
  else
    cp ${NUTTXDIR}/defconfig $1
  fi
}

function build_board_cmake()
{
  echo -e "Build command line:"
  echo -e "  cd ${NUTTXDIR}"
  echo -e "  cmake -B build -DBOARD_CONFIG=$1 -GNinja"
  echo -e "  cmake --build build -t savedefconfig"

  cd ${NUTTXDIR}
  if ! cmake -B build -DBOARD_CONFIG=$1 -GNinja; then
    rm build -rf
    if ! cmake -B build -DBOARD_CONFIG=$1 -GNinja; then
      echo "Error: ############# config ${1} fail ##############"
      rm build -rf
      exit 1
    fi
  fi
  
  if [ $# -eq 1 ] && ! cmake --build build; then
    echo "Error: ############# build ${1} fail ##############"
    exit 2
  elif [ $# -ge 2 ] && ! cmake --build build -t ${@:2}; then
    echo "Error: ############# build -t ${@:2} fail ##############"
    exit 2
  fi


  if [ "${2}" == "distclean" ]; then
    rm build -rf
    return;
  fi

  cmake --build build -t savedefconfig
  if [ ! -d $1 ]; then
    cp ${NUTTXDIR}/build/defconfig ${ROOTDIR}/nuttx/boards/*/*/${1/[:|\/]//configs/}
  else
    cp ${NUTTXDIR}/build/defconfig $1
  fi
}

if [ $# == 0 ]; then
  echo "Usage: $0 <board-name>:<config-name> [make options]"
  echo "       $0 <config-path> [make options]"
  exit 1
fi

board_config=$1
shift

if [ -d ${ROOTDIR}/${board_config} ]; then
  build_board_cmake ${ROOTDIR}/${board_config} $*
else
  build_board_cmake ${board_config} $*
fi

