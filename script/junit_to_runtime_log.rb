#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts JUnit XML test results into a parallel_test runtime log.
# Usage: ruby script/junit_to_runtime_log.rb <output_file> <xml_glob>
# Example: ruby script/junit_to_runtime_log.rb tmp/parallel_runtime_rspec.log "Test Results Group*/*.xml"

require 'rexml/document'

output_file = ARGV[0] || 'tmp/parallel_runtime_rspec.log'
xml_glob = ARGV[1] || 'Test Results Group*/*.xml'

file_times = Hash.new(0.0)

Dir.glob(xml_glob).each do |xml_path|
  doc = REXML::Document.new(File.read(xml_path))
  doc.elements.each('//testcase') do |tc|
    file = tc.attributes['file']
    time = tc.attributes['time']
    next unless file && time

    # Normalize path: remove leading ./ if present
    file = file.sub(%r{^\./}, '')
    file_times[file] += time.to_f
  end
end

if file_times.empty?
  warn 'No test timing data found in JUnit XML files.'
  exit 0
end

File.open(output_file, 'w') do |f|
  file_times.sort_by { |path, _| path }.each do |path, time|
    f.puts "#{path}:#{format('%.4f', time)}"
  end
end

warn "Generated #{output_file} with #{file_times.size} entries"
