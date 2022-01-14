#!/usr/bin/env ruby

# frozen_string_literal: true

require 'google/cloud/bigquery'
require 'nokogiri'

class TestStatsToBigquery
  STATS_TABLE = 'rspec_statistics'
  FAILURES_TABLE = 'rspec_failing_tests'
  COVERAGE_TABLE = 'coverage_statistics'
  DATASET = 'vsp_testing_tools'

  attr_reader :bigquery, :dataset, :failures

  def initialize
    @bigquery = Google::Cloud::Bigquery.new
    @dataset = bigquery.dataset DATASET, skip_lookup: true
    @failures = []
  end

  # rubocop:disable Metrics/ParameterLists
  def upload_stats_data(total_tests = 0, total_failures = 0, total_skipped = 0, total_time = 0)
    date = 0

    Dir['Test Results/*.xml'].each_with_index do |results_file, index|
      doc = File.open(results_file) { |f| Nokogiri::XML(f) }
      date = doc.xpath('//testsuite/@timestamp').to_s.split('T')[0] if index.zero?
      time = doc.xpath('//testsuite/@time').to_s.to_i
      total_time = time if time > total_time
      total_tests += doc.xpath('//testsuite/@tests').to_s.to_i
      failures = doc.xpath('//testsuite/@failures').to_s.to_i
      @failures << doc if failures.positive?
      total_failures += failures
      total_skipped += doc.xpath('//testsuite/@skipped').to_s.to_i
    end

    data = [{
      date: date,
      total_tests: total_tests,
      total_failures: total_failures,
      total_skipped: total_skipped,
      total_time: total_time
    }]

    upload_data(STATS_TABLE, data, 'statistics')
  end
  # rubocop:enable Metrics/ParameterLists

  def upload_coverage_data
    coverage_data = Nokogiri::HTML.parse(File.read('Coverage Report/index.html'))
    date = coverage_data.xpath("//*[@class='timeago']").text.split('T')[0]
    coverage_by_module = coverage_data.xpath('//h2').map do |module_data|
      formatted_data = module_data.text.gsub("\n", '').gsub(' ', '').split('%')[0].split('(')
      {
        date: date,
        module_name: formatted_data[0],
        coverage: formatted_data[1]
      }
    end

    upload_data(COVERAGE_TABLE, coverage_by_module, 'test coverage')
  end

  def upload_failure_data
    return 'No failures to upload to BigQuery.' if @failures.empty?

    @failures.each do |failure|
      date = failure.xpath('//testsuite/@timestamp').to_s.split('T')[0]
      failing_specs = failure.search('//*/failure/..')
      failing_specs.each do |failing_spec|
        data =  [{
          spec: failing_spec.attribute('file'),
          name: failing_spec.attribute('name'),
          date: date
        }]
        upload_data(FAILURES_TABLE, data, 'failure')
      end
    end
    'Uploaded RSpec failure data to BigQuery.'
  end

  private

  def upload_data(table, data, message)
    data_table = @dataset.table table, skip_lookup: true

    # rubocop:disable Rails/SkipsModelValidations
    response = data_table.insert data
    # rubocop:enable Rails/SkipsModelValidations
    if response.success?
      "Uploaded RSpec #{message} data to BigQuery."
    else
      raise("Failed to upload RSpec #{message} data to BigQuery.")
    end
  end
end

if $PROGRAM_NAME == __FILE__
  test_stats_to_bigquery = TestStatsToBigquery.new
  puts test_stats_to_bigquery.upload_stats_data
  puts test_stats_to_bigquery.upload_failure_data
  puts test_stats_to_bigquery.upload_coverage_data if ENV['BRANCH_NAME'] == 'refs/heads/master'
end
