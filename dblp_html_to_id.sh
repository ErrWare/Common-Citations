#!/bin/sh

cat - | pup 'li[class="details"] a' | grep "^<a" | grep -o 'https:[^"]\+' | sed -n 's/.html$//p'
