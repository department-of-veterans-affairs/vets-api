# frozen_string_literal: true

require 'rails_helper'

describe Benchmark::Performance do
  let(:metric) { 'initial_pageload' }
  let(:stats_d_key) { "#{Benchmark::Performance::FE}.#{Benchmark::Performance::PAGE_PERFORMANCE}.#{metric}" }
  let(:page_id) { 'some_unique_page_identifier' }

  describe '.track' do
    it 'calls StatsD.measure with the passed benchmarking data' do
      expect do
        Benchmark::Performance.track(stats_d_key, 100, tags: [page_id])
      end.to trigger_statsd_measure(
        stats_d_key,
        tags: [page_id],
        times: 1,
        value: 100
      )
    end
  end

  describe '.by_page_and_metric' do
    it 'calls StatsD.measure with benchmark data for the passed page and metric.' do
      expect do
        Benchmark::Performance.by_page_and_metric(metric, 100, page_id)
      end.to trigger_statsd_measure(
        stats_d_key,
        tags: [page_id],
        times: 1,
        value: 100
      )
    end
  end
end
