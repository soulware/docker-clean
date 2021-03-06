#!/usr/bin/env bats

# PRODUCTION Bats Tests for Travis CI

# Initial pass at testing for docker-clean
# These tests simply test each of the options currently available

# To run the tests locally run brew install bats or
# sudo apt-get install bats and then bats batsTest.bats

# WARNING: Runing these tests will clear all of your images/Containers

@test "Check that docker client is available" {
  command -v docker
}

@test "Run docker ps (check daemon connectivity)" {
  run docker ps
  [ $status = 0 ]
}

@test "Docker Clean Version echoes" {
  run ./docker-clean -v
  [ $status = 0 ]
}

@test "Default build and clean testing helper functions" {
  build
  [ $status = 0 ]

  clean
  runningContainers="$(docker ps -aq)"
  [ ! $runningContainers ]
  }

@test "Help menu opens" {
  # On -h flag
  run ./docker-clean -h
  [[ ${lines[0]} =~ "Options:" ]]
  run ./docker-clean --help
  [[ ${lines[0]} =~ "Options:" ]]

  # On unspecified tag
  run ./docker-clean -z
  [[ ${lines[0]} =~ "Options:" ]]
  #clean
}

@test "Test container stopping (-s --stop)" {
  build
  [ $status = 0 ]
  runningContainers="$(docker ps -q)"
  [ $runningContainers ]
  run ./docker-clean -s
  runningContainers="$(docker ps -q)"
  [ ! $runningContainers ]

  clean
}

@test "Clean Containers test" {
  stoppedContainers="$(docker ps -a)"
  untaggedImages="$(docker images -aq --filter "dangling=true")"
  run docker kill $(docker ps -a -q)
  [ "$stoppedContainers" ]

  run ./docker-clean
  stoppedContainers="$(docker ps -qf STATUS=exited )"
  createdContainers="$(docker ps -qf STATUS=created)"
  [ ! "$stoppedContainers" ]
  [ ! "$createdContainers" ]

  clean
}

@test "Clean All Containers Test" {
  build
  [ $status = 0 ]
  allContainers="$(docker ps -a -q)"
  [ "$allContainers" ]
  run ./docker-clean -c
  allContainers="$(docker ps -a -q)"
  [ ! "$allContainers" ]

  clean
}

@test "Clean images (not all)" {
  skip
  build
  [ $status = 0 ]
  untaggedImages="$(docker images -aq --filter "dangling=true")"
  [ "$untaggedImages" ]

  run ./docker-clean
  untaggedImages="$(docker images -aq --filter "dangling=true")"
  [ ! "$untaggedImages" ]

  clean
}

@test "Clean all images function" {
  build
  [ $status = 0 ]
  listedImages="$(docker images -aq)"
  [ "$listedImages" ]

  run ./docker-clean --images
  listedImages="$(docker images -aq)"
  [ ! "$listedImages" ]

  clean
}

@test "Clean Volumes function" {
  skip "Work in progress"
  build
  [ $status = 0 ]

  clean
}


# TODO figure out the -qf STATUS exited
# TODO Write test with an untagged image
@test "Default run through -- docker-clean (without arguments)" {
  build
  [ $status = 0 ]
  stoppedContainers="$(docker ps -a)"
  untaggedImages="$(docker images -aq --filter "dangling=true")"
  run docker kill $(docker ps -a -q)
  [ "$stoppedContainers" ]
  #[ "$untaggedImages" ]
  run ./docker-clean

  stoppedContainers="$(docker ps -qf STATUS=exited )"
  createdContainers="$(docker ps -qf STATUS=created)"
  [ ! "$stoppedContainers" ]
  [ ! "$createdContainers" ]
  [ ! "$untaggedImages" ]

  clean
}

# Test for counting correctly
@test "Testing counting function" {
  build
  [ $status = 0 ]
  run docker kill $(docker ps -a -q)
  run ./docker-clean
  [[ ${lines[0]} =~ "Cleaning containers..." ]]
  [[ ${lines[1]} =~ "1" ]]
  run ./docker-clean -i
  [[ ${lines[1]} =~ "Cleaning images..."  ]]
  [[ ${lines[2]} =~ "4" ]]

  clean
}

# Tests logging outputs properly
@test "Verbose log function (-l --log)" {
    build
    [ $status = 0 ]
    docker stop "$(docker ps -q)"
    stoppedContainers="$(docker ps -a -q)"
    run ./docker-clean -l 2>&1
    [[ $output =~ "$stoppedContainers" ]]

    clean
}
# Testing for successful restart
@test "Restart function" {
    operating_system=$(testOS)
    if [[ $operating_system =~ "mac" || $operating_system =~ 'windows' ]]; then
      ./docker-clean -a | grep 'started'
      run docker ps &>/dev/null
      [ $status = 0 ]
    elif [[ $operating_system =~ "linux" ]]; then
      ./docker-clean -a | grep 'stop'
      #ps -e | grep 'docker'

      run docker ps &>/dev/null
      [ $status = 0 ]
    else
      echo "Operating system not valid"
      [[ false ]]
    fi
}

# Helper FUNCTIONS

function build() {
    if [ $(docker ps -a -q) ]; then
      docker rm -f $(docker ps -a -q)
    fi
    run docker pull zzrot/whale-awkward
    run docker pull zzrot/alpine-ghost
    run docker pull zzrot/alpine-node
    run docker run -d zzrot/alpine-caddy
}

function clean() {
  run docker kill $(docker ps -a -q)
  run docker rm -f $(docker ps -a -q)
  run docker rmi -f $(docker images -aq)
}

## ** Script for testing os **
# Credit https://stackoverflow.com/questions/3466166/how-to-check-if-running-in-cygwin-mac-or-linux/17072017#17072017?newreg=b1cdf253d60546f0acfb73e0351ea8be
# Echo mac for Mac OS X, echo linux for GNU/Linux, echo windows for Window
function testOS {
  if [ "$(uname)" == "Darwin" ]; then
      # Do something under Mac OS X platform
      echo mac
  elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
      # Do something under GNU/Linux platform
      echo linux
  elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
      # Do something under Windows NT platform
      echo windows
  fi
}
