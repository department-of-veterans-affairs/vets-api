#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone SimpleCov collation script — no Rails environment needed.
# Merges per-shard .resultset.json files and generates the coverage report.
#
# Usage: ruby script/coverage_collate.rb [glob_pattern]
# Default: simplecov-resultset-*/.resultset.json

require 'simplecov'

glob = ARGV[0] || 'simplecov-resultset-*/.resultset.json'
files = Dir.glob(glob)

abort "No resultset files found matching: #{glob}" if files.empty?

warn "Collating #{files.size} coverage result sets..."
SimpleCov.collate(files)
warn 'Coverage collation complete.'
