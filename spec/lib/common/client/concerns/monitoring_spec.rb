# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::Client::Concerns::Monitoring, type: :model do
  module Specs
    module Common
      module Client
        class MonitoringTestService < ::Common::Client::Base
          STATSD_KEY_PREFIX = 'fooservice'
          include ::Common::Client::Concerns::Monitoring
          configuration DefaultConfiguration

          def request(*args)
            with_monitoring { super }
          end
        end
      end
    end
  end

  let(:service) { Specs::Common::Client::MonitoringTestService.new }
  let(:total_key) { "#{service.class.const_get('STATSD_KEY_PREFIX')}.request.total" }
  let(:fail_key) { "#{service.class.const_get('STATSD_KEY_PREFIX')}.request.fail" }

  it 'increments the total' do
    VCR.use_cassette('shared/success') do
      expect(StatsD).to receive(:increment).once.with(total_key)
      service.request(:get, nil)
      redis_key = StatsDMetric.find(total_key)
      expect(redis_key).to be_truthy
    end
  end

  context 'when a request fails' do
    it 'increments the failure total' do
      VCR.use_cassette('shared/failure') do
        expect(StatsD).to receive(:increment).once.with(fail_key,
                                                        tags: ['error:CommonClientErrorsClientError', 'status:404'])
        expect(StatsD).to receive(:increment).once.with(total_key)
        expect { service.request(:get, nil) }.to raise_error(Common::Client::Errors::ClientError)
        redis_key = StatsDMetric.find(fail_key)
        expect(redis_key).to be_truthy
      end
    end
  end
end
