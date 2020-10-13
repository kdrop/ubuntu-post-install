#!/usr/bin/env bash

# This is a bash utility to test the script in docker container
# Version:2.0
# Author: Prasad Tengse
# Licence: GPLv3
# Github Repository: https://github.com/tprasadtp/after-effects-ubuntu

set -eo pipefail

function display_usage()
{
#Prints out help menu
cat <<EOF
Bash script to run test containers

Usage: ${YELLOW}${SCRIPT}   [options]${NC}
[-d --distro]          [Distribution Base (ubuntu/debian)]
[-r --release]         [Distribution Release (focal/buster etc..)]
[-s --shell]           [Drop into a bash shell]
[-h --help]            [Display this help message]

EOF
}

function main()
{
  # No args just run the setup function
  if [[ $# -eq 0 ]]; then
    echo -e "\e[91mNot enought arguments See usage below. \e[39m";
    display_usage
    exit 1
  fi

  declare -a EXTRA_ARGS
  declare -a DOCKER_RUN_ARGS

  while [[ ${1} != "" ]]; do
    case ${1} in
      -h | --help )         display_usage;exit 0;;
      -d | --distro)        shift;distro_name=${1};;
      -r | --release)       shift;release_name=${1};;
      -s | --shell)         give_shell="true";;
      -b | --build)         build_image="true";;
      --fix)                EXTRA_ARGS+=('--fix');;
      --fix-lts)            EXTRA_ARGS+=('--fix-mode-lts');;
      --pre)                EXTRA_ARGS+=('--pre-release');;
      --sv)                 EXTRA_ARGS+=('--skip-version-check');;
      * )                   echo -e "\e[91mInvalid argument(s). See usage below. \e[39m";
                            display_usage;
                            exit 1;;
    esac
    shift
  done

  if [[ -z $distro_name ]] || [[ -z $release_name ]]; then
    echo -e "\e[91m--distro or --release not specified. See usage below. \e[39m";
    display_usage
    exit 1
  else
    docker_tag="${distro_name//[\/]/-}-${release_name}"

    if [[ -t 1 ]] && [[ ${AE_NON_INTERACTIVE} != "true" ]]; then
      echo "Terminal is interactive, using -it for docker runs"
      DOCKER_RUN_ARGS+=("-it")
    else
      echo "Terminal is NON interactive"
    fi

    # If Image needs to be built?
    if [[ $build_image == "true" ]]; then
      echo "➜ Building ae:${docker_tag}"
      docker build -t ae:"${docker_tag}" \
        --build-arg DISTRO="${distro_name}" \
        --build-arg CODE_NAME="${release_name}" \
        ./tests/docker
    fi


    if [[ $give_shell == "true" ]]; then
      echo "# Dropping you in ${docker_tag}"
      docker run --rm \
        --userns=host \
        -it \
        -e CI \
        -e DEBUG \
        -e GITHUB_ACTIONS \
        --hostname="${docker_tag}" \
        -v "$(pwd)":/shared \
        ae:"${docker_tag}" \
        bash -c "echo \"alias c='clear';alias e='exit';export PS1='\\e[31m\u@\h\\e[0m on \\e[32m\W\[\033[0;35m\] \[\033[1;36m\]\n🐳\\e[0m ➜ '\" >> ~/.bashrc && bash"
    else
      echo "# Running in docker ${docker_tag}"
      # turn on trace
      set -x
      docker run --rm \
        --userns=host \
        "${DOCKER_RUN_ARGS[@]}" \
        -e CI \
        -e DEBUG \
        -e GITHUB_ACTIONS \
        --hostname="${docker_tag}" \
        -v "$(pwd)":/shared \
        ae:"${docker_tag}" \
        ./after-effects \
        --simulate \
        --autopilot \
        --internal-ci-mode \
        --config-file config/test-suite.yml \
        "${EXTRA_ARGS[@]}"
        exit_code="$?"
      # turn of trace
      set +x

      echo ""
      echo "Script Exit code is $exit_code"
      if [[ $exit_code -ne 0 ]]; then
        exit "$exit_code"
      fi # exit code
    fi # shell
  fi # args
}

main "$@"
