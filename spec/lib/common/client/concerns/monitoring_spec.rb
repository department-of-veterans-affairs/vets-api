# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::Client::Monitoring, type: :model do
  module Specs
    module Common
      module Client
        class DefaultConfiguration < ::Common::Client::Configuration::REST
          def connection
            @conn ||= Faraday.new('http://example.com') do |faraday|
              faraday.adapter Faraday.default_adapter
              faraday.use     Faraday::Response::RaiseError
            end
          end

          def service_name
            'foo'
          end
        end

        class DefaultService < ::Common::Client::Base
          STATSD_KEY_PREFIX = 'fooservice'
          configuration DefaultConfiguration
          include ::Common::Client::Monitoring

          def request(*args)
            with_monitoring { super }
          end
        end
      end
    end
  end

  let(:service) { Specs::Common::Client::DefaultService.new }

  it 'increments the total' do
    VCR.use_cassette('shared/success', VCR::MATCH_EVERYTHING) do
      key = service.class.const_get('STATSD_KEY_PREFIX') + '.request.total'
      expect_any_instance_of(StatsD).to receive(:increment).with(key, tags: nil).once
      service.request(:get, nil)
    end
  end

  context 'when a request fails' do
    it 'increments the failure total' do
      VCR.use_cassette('shared/failure', VCR::MATCH_EVERYTHING) do
        key = service.class.const_get('STATSD_KEY_PREFIX') + '.request.fail'
        allow_any_instance_of(StatsD).to receive(:increment)
        expect_any_instance_of(StatsD).to receive(:increment).with(key, anything).at_least(:once)
        expect { service.request(:get, nil) }.to raise_error(Common::Client::Errors::ClientError)
      end
    end
  end
end
