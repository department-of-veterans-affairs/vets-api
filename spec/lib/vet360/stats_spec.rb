# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Stats do
  let(:statsd_prefix) { Vet360::Service::STATSD_KEY_PREFIX }

  describe '.increment' do
    it 'increments the StatsD Vet360 counter' do
      bucket1 = 'exceptions'
      bucket2 = 'VET360_ADDR133'

      expect { described_class.increment(bucket1, bucket2) }.to trigger_statsd_increment(
        "#{statsd_prefix}.#{bucket1}.#{bucket2.downcase}"
      )
    end

    it 'increments the StatsD Vet360 counter with a variable number of buckets passed' do
      bucket1 = 'bucket1'
      bucket2 = 'bucket2'
      bucket3 = 'bucket3'
      bucket4 = 'bucket4'

      expect { described_class.increment(bucket1, bucket2, bucket3, bucket4) }.to trigger_statsd_increment(
        "#{statsd_prefix}.#{bucket1}.#{bucket2}.#{bucket3}.#{bucket4}"
      )
    end
  end

  describe '.increment_transaction_results' do
    let(:success_status) { described_class::FINAL_SUCCESS.first }
    let(:failure_status) { described_class::FINAL_FAILURE.first }

    context 'when response contains a final success status' do
      it 'increments the StatsD Vet360 posts_and_puts success counter' do
        response = raw_vet360_transaction_response(success_status)

        expect { described_class.increment_transaction_results(response) }.to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.success"
        )
      end
    end

    context 'when response contains a final failure status' do
      it 'increments the StatsD Vet360 posts_and_puts failure counter' do
        response = raw_vet360_transaction_response(failure_status)

        expect { described_class.increment_transaction_results(response) }.to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.failure"
        )
      end
    end

    context 'when response is neither a success nor failure status' do
      it 'does not increment the StatsD Vet360 posts_and_puts counters', :aggregate_failures do
        response = raw_vet360_transaction_response('RECEIVED')

        expect { described_class.increment_transaction_results(response) }.not_to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.success"
        )
        expect { described_class.increment_transaction_results(response) }.not_to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.failure"
        )
      end
    end

    context 'when response body is nil' do
      it 'does not increment the StatsD Vet360 posts_and_puts counters', :aggregate_failures do
        expect { described_class.increment_transaction_results(nil) }.not_to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.success"
        )
        expect { described_class.increment_transaction_results(nil) }.not_to trigger_statsd_increment(
          "#{statsd_prefix}.posts_and_puts.failure"
        )
      end
    end

    context 'when bucket1 is provided as init_vet360_id' do
      let(:init_vet360) { 'init_vet360_id' }

      it 'increments the StatsD Vet360 init_vet360_id success counter' do
        response = raw_vet360_transaction_response(success_status)

        expect { described_class.increment_transaction_results(response, init_vet360) }.to trigger_statsd_increment(
          "#{statsd_prefix}.#{init_vet360}.success"
        )
      end

      it 'increments the StatsD Vet360 init_vet360_id failure counter' do
        response = raw_vet360_transaction_response(failure_status)

        expect { described_class.increment_transaction_results(response, init_vet360) }.to trigger_statsd_increment(
          "#{statsd_prefix}.#{init_vet360}.failure"
        )
      end
    end
  end

  describe '.increment_exception' do
    it 'increments the StatsD Vet360 exceptions counter' do
      tag = 'VET360_ADDR133'

      expect { described_class.increment_exception(tag) }.to trigger_statsd_increment(
        "#{statsd_prefix}.exceptions"
      )
    end
  end
end

def raw_vet360_transaction_response(tx_status)
  OpenStruct.new(body: { 'tx_status' => tx_status })
end
