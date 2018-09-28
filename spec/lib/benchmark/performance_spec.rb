# frozen_string_literal: true

require 'rails_helper'

describe Benchmark::Performance do
  let(:metric) { 'initial_page_load' }
  let(:stats_d_key) { "#{Benchmark::Performance::FE}.#{Benchmark::Performance::PAGE_PERFORMANCE}.#{metric}" }
  let(:page_id) { Benchmark::Whitelist::WHITELIST.first }

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
            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end

      context 'due to a duration not being provided' do
        it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
          expect { Benchmark::Performance.track(stats_d_key, nil, tags: [page_id]) }.to raise_error do |error|
            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end
    end

    context 'with a non-whitelisted tag' do
      it 'raises a Common::Exceptions::Forbidden error', :aggregate_failures do
        bad_tag = 'some_random_tag'

        expect { Benchmark::Performance.track(stats_d_key, 100, tags: [bad_tag]) }.to raise_error do |error|
          expect(error).to be_a Common::Exceptions::Forbidden
          expect(error.message).to eq 'Forbidden'
          expect(error.status_code).to eq 403
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
        tags: ["page_id:#{page_id}"],
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

  describe '.metrics_for_page' do
    let(:metrics_data) do
      [
        { metric: metric, duration: 1234.56 },
        { metric: 'time_to_paint', duration: 123.45 }
      ].as_json
    end

    it 'calls StatsD.measure for a given page, for a given set of metrics and durations' do
      expect(StatsD).to receive(:measure).twice

      Benchmark::Performance.metrics_for_page(page_id, metrics_data)
    end

    it 'calls StatsD.measure with the expected benchmark data' do
      expect do
        Benchmark::Performance.metrics_for_page(page_id, metrics_data)
      end.to trigger_statsd_measure(
        stats_d_key,
        tags: ["page_id:#{page_id}"],
        times: 1,
        value: 1234.56
      )
    end

    it 'returns an array of StatsD::Instrument::Metric objects' do
      results = Benchmark::Performance.metrics_for_page(page_id, metrics_data)

      results.each do |result|
        expect(result.class).to eq StatsD::Instrument::Metric
      end
    end

    context 'when expected data is not provided' do
      context 'for the "metric" attribute' do
        it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
          data_missing_metric = [
            { metric: metric, duration: 1234.56 },
            { duration: 123.45 }
          ].as_json

          expect { Benchmark::Performance.metrics_for_page(page_id, data_missing_metric) }.to raise_error do |error|
            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end

      context 'for the "duration" attribute' do
        it 'raises a Common::Exceptions::ParameterMissing error', :aggregate_failures do
          data_missing_duration = [
            { metric: metric, duration: 1234.56 },
            { metric: 'time_to_paint' }
          ].as_json

          expect { Benchmark::Performance.metrics_for_page(page_id, data_missing_duration) }.to raise_error do |error|
            expect(error).to be_a Common::Exceptions::ParameterMissing
            expect(error.message).to eq 'Missing parameter'
            expect(error.status_code).to eq 400
          end
        end
      end
    end
  end
end
