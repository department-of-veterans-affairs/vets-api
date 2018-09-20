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

    context 'with an ArgumentError' do
      context 'due to a StatsD key not being provided' do
        it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
          expect { Benchmark::Performance.track(nil, 100, tags: [page_id]) }.to raise_error do |error|
            error_detail = error.errors.first.detail

            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error_detail).to eq 'Metric :name is required.'
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end

      context 'due to a duration not being provided' do
        it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
          expect { Benchmark::Performance.track(stats_d_key, nil, tags: [page_id]) }.to raise_error do |error|
            error_detail = error.errors.first.detail

            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error_detail).to eq 'A value is required for metric type :ms.'
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end
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

    context 'when "metric" attribute is missing' do
      it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
        expect { Benchmark::Performance.by_page_and_metric(nil, 100, page_id) }.to raise_error do |error|
          expect(error).to be_a Common::Exceptions::ParameterMissing
          expect(error.message).to eq 'Missing parameter'
          expect(error.status_code).to eq 400
        end
      end
    end
  end
  end
end
