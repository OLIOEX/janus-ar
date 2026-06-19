#!/bin/bash
rm janus-ar-*.gem
gem build janus-ar.gemspec
gem push janus-ar-*.gem
