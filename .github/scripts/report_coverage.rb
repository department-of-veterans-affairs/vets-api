#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

options = { minimum: nil }

OptionParser.new do |opts|
  opts.banner = 'Usage: report_coverage.rb --summary-path PATH [--minimum VALUE]'
  opts.on('--summary-path PATH', 'Path to the coverage summary JSON file') { |path| options[:summary_path] = path }
  opts.on('--minimum VALUE', Float, 'Minimum required coverage percentage') { |value| options[:minimum] = value }
end.parse!

summary_path = options[:summary_path]
abort 'Missing required --summary-path option' if summary_path.nil? || summary_path.empty?

data = JSON.parse(File.read(summary_path))
covered_percent = data.dig('result', 'covered_percent')
abort "No covered_percent found in #{summary_path}" if covered_percent.nil?

covered_percent = covered_percent.to_f.round(2)
minimum = options[:minimum]

conclusion = if minimum
               covered_percent >= minimum ? 'success' : 'failure'
             else
               'neutral'
             end

puts "Coverage: #{covered_percent}%"
puts "Minimum required: #{minimum}%" if minimum

if (output_path = ENV['GITHUB_OUTPUT'])
  File.open(output_path, 'a') do |file|
    file.puts "covered_percent=#{covered_percent}"
    file.puts "minimum_required=#{minimum}" if minimum
    file.puts "conclusion=#{conclusion}"
  end
end

if (summary_file = ENV['GITHUB_STEP_SUMMARY'])
  lines = [
    '| Metric | Value |',
    '| --- | --- |',
    "| Covered | #{covered_percent}% |"
  ]
  lines << "| Minimum | #{minimum}% |" if minimum
  File.open(summary_file, 'a') { |file| file.puts lines.join("\n") }
end
