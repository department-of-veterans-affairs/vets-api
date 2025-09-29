# frozen_string_literal: true

namespace :coverage do
  desc 'Collates SimpleCov resultsets from all shards'
  task report: :environment do
    require 'simplecov'
    require 'json'

    SimpleCov.collate Dir['simplecov-resultset-*/.resultset.json'], 'rails' do
      # Pick formatters for final output
      formatter SimpleCov::Formatter::MultiFormatter.new([
                                                           SimpleCov::Formatter::SimpleFormatter,
                                                           SimpleCov::Formatter::HTMLFormatter
                                                         ])
      coverage_dir 'coverage'
    end

    # Export coverage percentage for coverage-check-action
    if File.exist?('coverage/.last_run.json')
      last_run = JSON.parse(File.read('coverage/.last_run.json'))
      puts "Raw coverage data: #{last_run.inspect}"

      pct = last_run.dig('result', 'line')
      puts "Extracted coverage percentage: #{pct.inspect}"

      # Ensure we have a valid number
      pct = pct.to_f if pct
      pct = 0.0 if pct.nil? || !pct.is_a?(Numeric)

      combined_data = { 'covered_percent' => pct }
      File.write('combined_coverage.json', JSON.pretty_generate(combined_data))
      puts "Created combined_coverage.json with #{pct}% coverage"
      puts "File contents: #{File.read('combined_coverage.json')}"
    else
      puts 'No coverage/.last_run.json found, creating default'
      combined_data = { 'covered_percent' => 0.0 }
      File.write('combined_coverage.json', JSON.pretty_generate(combined_data))
      puts "Created default combined_coverage.json: #{File.read('combined_coverage.json')}"
    end
  end
end
