# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::Client::Monitoring, type: :model do
  module Specs
    module Common
      module Client
        class MonitoringTestConfiguration < ::Common::Client::Configuration::REST
          def connection
            @conn ||= Faraday.new('http://example.com') do |faraday|
              faraday.use     :breakers
              faraday.use     Faraday::Response::RaiseError
              faraday.use     :remove_cookies
              faraday.adapter :httpclient
            end
          end

          def service_name
            'foo'
          end
        end

        class MonitoringTestService < ::Common::Client::Base
          STATSD_KEY_PREFIX = 'fooservice'
          configuration MonitoringTestConfiguration
          include ::Common::Client::Monitoring

          def request(*args)
            with_monitoring { super }
          end
        end
      end
    end
  end

  let(:service) { Specs::Common::Client::MonitoringTestService.new }
  let(:total_key) { service.class.const_get('STATSD_KEY_PREFIX') + '.request.total' }
  let(:fail_key) { service.class.const_get('STATSD_KEY_PREFIX') + '.request.fail' }

  it 'increments the total' do
    VCR.use_cassette('shared/success') do
      service.request(:get, nil)
      redis_key = StatsDMetric.find(total_key)
      expect(redis_key).to be
    end
  end

  context 'when a request fails' do
    it 'increments the failure total' do
      VCR.use_cassette('shared/failure') do
        expect { service.request(:get, nil) }.to raise_error(Common::Client::Errors::ClientError)
        redis_key = StatsDMetric.find(fail_key)
        expect(redis_key).to be
      end
    end
  end
end
