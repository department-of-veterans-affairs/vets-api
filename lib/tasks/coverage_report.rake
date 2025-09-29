# frozen_string_literal: true

namespace :coverage do
  desc 'Collates SimpleCov resultsets from all shards'
  task report: :environment do
    require 'simplecov'
    require 'json'

    result = SimpleCov.collate Dir['simplecov-resultset-*/.resultset.json'], 'rails' do
      # Pick formatters for final output
      formatter SimpleCov::Formatter::MultiFormatter.new([
                                                           SimpleCov::Formatter::SimpleFormatter,
                                                           SimpleCov::Formatter::HTMLFormatter
                                                         ])
      coverage_dir 'coverage'
    end

    warn 'SimpleCov did not return a result; creating empty coverage summary' if result.nil?

    covered_percent = result&.covered_percent
    puts "Extracted coverage percentage: #{covered_percent.inspect}"

    covered_percent = covered_percent.to_f.round(2)

    summary = { 'result' => { 'covered_percent' => covered_percent } }
    File.write('coverage_summary.json', JSON.pretty_generate(summary))
    puts "Created coverage_summary.json with #{covered_percent}% coverage"
    puts "File contents: #{File.read('coverage_summary.json')}"
  end
end
