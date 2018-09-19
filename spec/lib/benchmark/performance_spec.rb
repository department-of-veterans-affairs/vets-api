# frozen_string_literal: true

require 'rails_helper'

describe Benchmark::Performance do
  let(:stats_d_key) { "#{Benchmark::Performance::FE}.#{Benchmark::Performance::PAGE_LOAD}" }
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

  describe '.page_load' do
    it 'calls StatsD.measure with frontend page load data' do
      expect do
        Benchmark::Performance.page_load(100, page_id)
      end.to trigger_statsd_measure(
        stats_d_key,
        tags: [page_id],
        times: 1,
        value: 100
      )
    end
  end
end
