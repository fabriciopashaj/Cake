#!/usr/bin/env bash

if [ -n $CC ]
then
  CC=cc
fi

$CC -o fsinter.o -fPIC -c fsinter.c && $CC -o fsinter.so -shared fsinter.o
