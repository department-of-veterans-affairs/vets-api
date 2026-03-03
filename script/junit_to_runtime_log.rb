#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts JUnit XML test results into a parallel_test runtime log and
# identifies slow spec files / examples for CI annotation.
#
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

  # Returns a module/service group key for a file path.
  # Related source and spec files produce the same key so that touching
  # a source file triggers annotations on slow specs in that area.
  #
  # Examples:
  #   modules/check_in/app/controllers/foo.rb  → "modules/check_in"
  #   modules/check_in/spec/requests/foo.rb    → "modules/check_in"
  #   app/models/user.rb                       → "models"
  #   spec/models/user_spec.rb                 → "models"
  #   app/controllers/v0/foo_controller.rb     → "controllers"
  #   spec/requests/v0/foo_spec.rb             → "controllers"
  #   lib/rx/client.rb                         → "lib/rx"
  #   spec/lib/rx/client_spec.rb               → "lib/rx"
  def self.group_for(path)
    parts = path.sub(%r{^\./}, '').split('/')
    first = parts[0]
    second = parts[1]
    has_second = parts.size >= 2

    # modules/<name>/** → modules/<name>
    return "#{first}/#{second}" if first == 'modules' && has_second

    # spec/lib/<name>/** → lib/<name>
    return "lib/#{parts[2]}" if first == 'spec' && second == 'lib' && parts.size >= 3

    # spec/<type>/** → <type> (with requests→controllers mapping)
    if first == 'spec' && has_second
      return second == 'requests' ? 'controllers' : second
    end

    # lib/<name>/** → lib/<name>
    return "lib/#{second}" if first == 'lib' && has_second

    # app/<type>/** → <type>
    return second if first == 'app' && has_second

    # Fallback: first path segment
    first
  end

  # Returns slow spec files whose module/service group was touched by changed_files.
  # Each result is { file:, time:, pct: }.
  def self.find_slow_files(file_times, changed_files, threshold_pct: 2.0)
    total_time = file_times.values.sum
    return [] if total_time.zero?

    changed_groups = changed_files.to_set { |f| group_for(f) }

    results = file_times.filter_map do |file, time|
      pct = (time / total_time) * 100.0
      next unless pct >= threshold_pct
      next unless changed_groups.include?(group_for(file))

      { file:, time:, pct: }
    end
    results.sort_by { |h| -h[:pct] }
  end

  # Returns individual slow test examples whose module/service group was touched.
  # Each result is { file:, name:, time: }.
  def self.find_slow_examples(xml_paths, changed_files, threshold_sec: 20.0)
    changed_groups = changed_files.to_set { |f| group_for(f) }

    slow = []
    xml_paths.each do |xml_path|
      doc = REXML::Document.new(File.read(xml_path))
      doc.elements.each('//testcase') do |tc|
        file = tc.attributes['file']
        time = tc.attributes['time']&.to_f
        name = tc.attributes['name']
        next unless file && time && time >= threshold_sec

        file = file.sub(%r{^\./}, '')
        next unless changed_groups.include?(group_for(file))

        slow << { file:, name:, time: }
      end
    end

    slow.sort_by { |h| -h[:time] }
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
