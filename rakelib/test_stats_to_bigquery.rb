#!/usr/bin/env ruby

# frozen_string_literal: true

require 'google/cloud/bigquery'
require 'nokogiri'

class TestStatsToBigquery
  TABLE = 'rspec_statistics'
  FAILURES_TABLE = 'rspec_failing_tests'
  DATASET = 'vsp_testing_tools'

  attr_reader :bigquery, :dataset, :failures

  def initialize
    @bigquery = Google::Cloud::Bigquery.new
    @dataset = bigquery.dataset DATASET, skip_lookup: true
    @failures = []
  end

  # rubocop:disable Metrics/ParameterLists
  def read_files(total_tests = 0, total_failures = 0, total_skipped = 0, total_time = 0)
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

    [{
      date: date,
      total_tests: total_tests,
      total_failures: total_failures,
      total_skipped: total_skipped,
      total_time: total_time
    }]
  end
  # rubocop:enable Metrics/ParameterLists

  def upload_test_stats
    table = @dataset.table TABLE, skip_lookup: true
    # rubocop:disable Rails/SkipsModelValidations
    response = table.insert read_files
    # rubocop:enable Rails/SkipsModelValidations
    if response.success?
      puts 'Uploaded RSpec data to BigQuery.'
    else
      raise('Failed to upload RSpec data to BigQuery.')
    end
    upload_failure_data
  end

  private

  def upload_failure_data
    table = @dataset.table FAILURES_TABLE, skip_lookup: true
    @failures.each do |failure|
      date = failure.xpath('//testsuite/@timestamp').to_s.split('T')[0]
      failing_specs = failure.search('//*/failure/..')
      failing_specs.each do |failing_spec|
        data =  [{
          spec: failing_spec.attribute('file'),
          name: failing_spec.attribute('name'),
          date: date
        }]
        # rubocop:disable Rails/SkipsModelValidations
        response = table.insert data
        # rubocop:enable Rails/SkipsModelValidations
        if response.success?
          puts 'Uploaded RSpec failure data to BigQuery.'
        else
          raise('Failed to upload RSpec failure data to BigQuery.')
        end
      end
    end
  end
end

TestStatsToBigquery.new.upload_test_stats if $PROGRAM_NAME == __FILE__
