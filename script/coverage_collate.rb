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

# Resultsets contain absolute paths from Docker test containers (/app/...).
# Rewrite them to match the current workspace so SimpleCov can find source files
# and correctly calculate coverage (including lines in files that weren't loaded).
workspace_root = Dir.pwd
files.each do |file|
  content = File.read(file)
  # Only replace paths at JSON key boundaries (after opening quote) to avoid
  # false matches in subdirectory names like modules/my_health/app/...
  File.write(file, content) if content.gsub!('"/app/', "\"#{workspace_root}/")
end

warn "Collating #{files.size} coverage result sets..."
SimpleCov.collate(files)
warn 'Coverage collation complete.'
