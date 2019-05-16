#!/usr/bin/env python

from __future__ import print_function
import sys
import re
import os

script_dir = os.path.dirname(os.path.realpath(__file__))

try:
  image_name = sys.argv[1]
  m = re.match(".*/(.*?):(.*)", image_name)
  tag_args = "{} {} {}".format(m.group(1), m.group(2), m.group(2))
  cmd = '{}/docker-tag.sh {}'.format(script_dir, tag_args)
  print(cmd)
  os.system(cmd)
except IndexError:
  print('Usage: docker-tag-publish.py <full_image_name>')
  sys.exit(1)
  
