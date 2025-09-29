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
      pct = last_run.dig('result', 'line') || 0
      combined_data = { 'covered_percent' => pct }
      File.write('combined_coverage.json', JSON.pretty_generate(combined_data))
      puts "Created combined_coverage.json with #{pct}% coverage"
    else
      puts 'No coverage/.last_run.json found'
      exit 1
    end
  end
end
