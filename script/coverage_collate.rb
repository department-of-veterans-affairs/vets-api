#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone SimpleCov collation script — no Rails environment needed.
# Merges per-shard .resultset.json files and generates the coverage report.
#
# Usage: ruby script/coverage_collate.rb [glob_pattern]
# Default: simplecov-resultset-*/.resultset.json

require 'simplecov'

module CoverageCollate
  # Resultsets contain absolute paths from Docker test containers (/app/...).
  # Rewrite them to match the current workspace so SimpleCov can find source files
  # and correctly calculate coverage (including lines in files that weren't loaded).
  def self.rewrite_paths(files, workspace_root)
    files.each do |file|
      content = File.read(file)
      # Only replace paths at JSON key boundaries (after opening quote) to avoid
      # false matches in subdirectory names like modules/my_health/app/...
      File.write(file, content) if content.gsub!('"/app/', "\"#{workspace_root}/")
    end
  end

  def self.run(glob: 'simplecov-resultset-*/.resultset.json', workspace_root: Dir.pwd)
    files = Dir.glob(glob)
    abort "No resultset files found matching: #{glob}" if files.empty?

    rewrite_paths(files, workspace_root)

    warn "Collating #{files.size} coverage result sets..."
    SimpleCov.collate(files)
    warn 'Coverage collation complete.'
  end
end

CoverageCollate.run(glob: ARGV[0] || 'simplecov-resultset-*/.resultset.json') if __FILE__ == $PROGRAM_NAME
