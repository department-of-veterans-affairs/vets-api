#!/usr/bin/env ruby
# frozen_string_literal: true

# Emits GitHub Actions ::warning annotations for slow spec files and examples
# that belong to the same module/service as files changed in the PR.
#
# Usage: ruby script/slow_spec_annotator.rb <changed_files_path> [xml_glob] [file_pct] [example_sec]
#
# Environment variable overrides for thresholds:
#   SLOW_SPEC_FILE_PCT    – file-level threshold as % of total runtime (default: 2.0)
#   SLOW_SPEC_EXAMPLE_SEC – example-level threshold in seconds (default: 20.0)

require_relative 'junit_to_runtime_log'

changed_files_path = ARGV[0]
xml_glob           = ARGV[1] || 'Test Results Group*/*.xml'
file_pct           = (ARGV[2] || ENV.fetch('SLOW_SPEC_FILE_PCT', '2.0')).to_f
file_pct           = 2.0 unless file_pct.positive?
example_sec        = (ARGV[3] || ENV.fetch('SLOW_SPEC_EXAMPLE_SEC', '20.0')).to_f
example_sec        = 20.0 unless example_sec.positive?

unless changed_files_path && File.exist?(changed_files_path)
  warn 'No changed files list provided or file does not exist, skipping.'
  exit 0
end

changed_files = File.readlines(changed_files_path).map(&:strip).reject(&:empty?)
if changed_files.empty?
  warn 'Changed files list is empty, skipping.'
  exit 0
end

xml_paths = Dir.glob(xml_glob)
if xml_paths.empty?
  warn 'No JUnit XML files found, skipping.'
  exit 0
end

file_times    = JunitToRuntimeLog.aggregate_times(xml_paths)
slow_files    = JunitToRuntimeLog.find_slow_files(file_times, changed_files, threshold_pct: file_pct)
slow_examples = JunitToRuntimeLog.find_slow_examples(xml_paths, changed_files, threshold_sec: example_sec)

slow_files.each do |sf|
  puts "::warning file=#{sf[:file]}::" \
       "Slow spec file: #{sf[:time].round(1)}s " \
       "(#{sf[:pct].round(1)}% of total test runtime, threshold: #{file_pct}%)"
end

slow_examples.each do |se|
  puts "::warning file=#{se[:file]}::" \
       "Slow test example: \"#{se[:name]}\" took #{se[:time].round(1)}s (threshold: #{example_sec}s)"
end

total = slow_files.size + slow_examples.size
if total.positive?
  warn "Emitted #{total} slow spec warning(s)"
else
  warn 'No slow spec warnings for changed files'
end
