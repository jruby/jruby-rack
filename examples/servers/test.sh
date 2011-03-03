#!/bin/bash

path=$(dirname $0)
if [ "$@" ]; then
  servers=( $@ )
else
  servers=( tc6 tc7 glassfish jboss5 jboss6 jetty6 jetty7 resin winstone )
  echo "Results" > results.txt
fi

for server in ${servers[*]}; do
  echo Starting $server...
  $path/server.sh $server start

  prefix=/sinatra
  case $server in
      gae|appengine)
	  prefix=
	  ;;
  esac

  echo Waiting for $server to start up...
  while ! curl -i -s http://localhost:8080/ | grep "HTTP/1.." > /dev/null; do
    sleep 2
  done

  echo Testing $server...

  curl -i -L --max-redirs 3 -s -vvv http://localhost:8080$prefix/ 2>&1 | tee index.out
  echo -n "$server: $prefix/ " >> results.txt
  if grep 'Congratulations!' index.out; then
    echo OK >> results.txt
  else
    echo FAIL >> results.txt
    echo Server $server FAILED $prefix/
  fi

  curl -i -L --max-redirs 3 -s -vvv http://localhost:8080$prefix/sub/ | tee sub.out
  echo -n "$server: $prefix/sub/ " >> results.txt
  if grep 'sub/index.html' sub.out; then
    echo OK >> results.txt
  else
    echo FAIL >> results.txt
    echo Server $server FAILED $prefix/sub/
  fi

  curl -i -L --max-redirs 3 -s -vvv http://localhost:8080$prefix/sub/path | tee path.out
  echo -n "$server: $prefix/sub/path " >> results.txt
  if grep 'sub/path.html' path.out; then
    echo OK >> results.txt
  else
    echo FAIL >> results.txt
    echo Server $server FAILED $prefix/sub/path
  fi

  curl -i -L --max-redirs 3 -s -vvv http://localhost:8080$prefix/env | tee env.out
  echo -n "$server: $prefix/env " >> results.txt
  if grep '200 OK' env.out; then
    echo OK >> results.txt
  else
    echo FAIL >> results.txt
    echo Server $server FAILED $prefix/env
  fi

  echo Stopping $server...
  $path/server.sh $server stop

  while curl -i -s http://localhost:8080/ | grep "HTTP/1.." > /dev/null; do
    sleep 2
  done
done

rm *.out