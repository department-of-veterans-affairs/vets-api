#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts JUnit XML test results into a parallel_test runtime log.
# Usage: ruby script/junit_to_runtime_log.rb <output_file> <xml_glob>
# Example: ruby script/junit_to_runtime_log.rb tmp/parallel_runtime_rspec.log "Test Results Group*/*.xml"

require 'rexml/document'

module JunitToRuntimeLog
  # Parse JUnit XML files and return a hash of { "spec/file_spec.rb" => total_seconds }
  def self.aggregate_times(xml_paths)
    file_times = Hash.new(0.0)

    xml_paths.each do |xml_path|
      xml_content = File.read(xml_path)
      if xml_content.include?('<!DOCTYPE')
        warn "Skipping #{xml_path}: DOCTYPE declarations are not allowed"
        next
      end

      doc = REXML::Document.new(xml_content)
      doc.elements.each('//testcase') do |tc|
        file = tc.attributes['file']
        time = tc.attributes['time']
        next unless file && time

        # Normalize path: remove leading ./ if present
        file = file.sub(%r{^\./}, '')
        file_times[file] += time.to_f
      end
    rescue REXML::ParseException, SystemCallError => e
      warn "Skipping #{xml_path}: #{e.class} - #{e.message}"
    end

    file_times
  end

  # Write a parallel_test runtime log from aggregated file times
  def self.write_log(file_times, output_file)
    File.open(output_file, 'w') do |f|
      file_times.sort_by { |path, _| path }.each do |path, time|
        f.puts "#{path}:#{format('%.4f', time)}"
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  output_file = ARGV[0] || 'tmp/parallel_runtime_rspec.log'
  xml_glob = ARGV[1] || 'Test Results Group*/*.xml'

  file_times = JunitToRuntimeLog.aggregate_times(Dir.glob(xml_glob))

  warn 'No test timing data found in JUnit XML files.' if file_times.empty?

  JunitToRuntimeLog.write_log(file_times, output_file)
  warn "Generated #{output_file} with #{file_times.size} entries"
end
