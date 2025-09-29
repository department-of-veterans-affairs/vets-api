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

    merged_result = SimpleCov::ResultMerger.merged_result

    fallback_percent = lambda do
      last_run_path = 'coverage/.last_run.json'

      unless File.exist?(last_run_path)
        warn 'No coverage/.last_run.json found; defaulting coverage to 0.0%'
        next 0.0
      end

      last_run = JSON.parse(File.read(last_run_path))
      raw_pct = last_run.dig('result', 'covered_percent') || last_run.dig('result', 'line')

      unless raw_pct
        warn 'coverage/.last_run.json missing covered_percent value; defaulting to 0.0%'
        next 0.0
      end

      raw_pct.to_f.round(2)
    rescue JSON::ParserError => e
      warn "Failed to parse coverage/.last_run.json (#{e.message}); defaulting coverage to 0.0%"
      0.0
    end

    covered_percent = if merged_result
                        merged_result.covered_percent.to_f.round(2)
                      else
                        warn 'SimpleCov did not return a merged result; falling back to coverage/.last_run.json'
                        fallback_percent.call
                      end

    puts "Extracted coverage percentage: #{covered_percent.inspect}"

    summary = { 'result' => { 'covered_percent' => covered_percent } }
    File.write('coverage_summary.json', JSON.pretty_generate(summary))
    puts "Created coverage_summary.json with #{covered_percent}% coverage"
    puts "File contents: #{File.read('coverage_summary.json')}"
  end
end
