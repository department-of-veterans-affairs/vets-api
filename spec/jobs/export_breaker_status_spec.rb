# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExportBreakerStatus do
  describe '#perform' do
    let(:service) do
      Breakers.client.services.first
    end
    let(:metric) { "api.external_service.#{service.name}.up" }

    before(:each) do
      # Reset breakers before each test
      Breakers.client.redis_connection.redis.flushdb
    end

    after(:all) do
      Breakers.client.redis_connection.redis.flushdb
    end

    context 'no failures on test service' do
      it 'reports up to statsd' do
        expect { subject.perform }.to trigger_statsd_gauge(metric, value: 1)
      end
    end

    context 'around outage on test service' do
      it 'reports down during an outage' do
        now = Time.current
        Timecop.freeze(now - 120)
        service.add_error # create outage
        expect { subject.perform }.to trigger_statsd_gauge(metric, value: 0)

        Timecop.freeze(now)
        service.latest_outage.end!
        expect { subject.perform }.to trigger_statsd_gauge(metric, value: 1)
      end
    end
  end
end
