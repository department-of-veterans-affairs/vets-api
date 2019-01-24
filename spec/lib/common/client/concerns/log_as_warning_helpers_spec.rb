# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Concerns::LogAsWarningHelpers do
  module Specs
    module Common
      module Client
        class DefaultConfiguration < ::Common::Client::Configuration::REST
          def connection
            @conn ||= Faraday.new('http://example.com') do |faraday|
              faraday.adapter Faraday.default_adapter
            end
          end

          def service_name
            'foo'
          end
        end

        class DefaultService < ::Common::Client::Base
          configuration DefaultConfiguration
          include ::Common::Client::Concerns::LogAsWarningHelpers

          def request(*args)
            warn_for_service_unavailable { super }
          end
        end
      end
    end
  end

  let(:service) { Specs::Common::Client::DefaultService.new }

  context 'when request raises a 503 backend service exception' do
    it 'should set log_as_warning in raven extra context' do
      expect(service).to receive(:connection).and_raise(
        Common::Exceptions::BackendServiceException.new(nil, {}, 503)
      )
      expect(Raven).to receive(:extra_context).with(log_as_warning: true)

      expect { service.send(:request, :get, nil) }.to raise_error(
        Common::Exceptions::BackendServiceException
      )
    end
  end

  context 'when request raises a non 503 error' do
    it 'should not set log_as_warning in raven extra context' do
      expect(service).to receive(:connection).and_raise(
        Common::Exceptions::BackendServiceException.new(nil, {}, 500)
      )
      expect(Raven).to_not receive(:extra_context).with(log_as_warning: true)

      expect { service.send(:request, :get, nil) }.to raise_error(
        Common::Exceptions::BackendServiceException
      )
    end
  end

  context 'when a request raises a 503 HTTPError error' do
    it 'should set log_as_warning in raven extra context' do
      expect(service).to receive(:connection).and_raise(Common::Client::Errors::HTTPError.new(nil, 503))

      expect(Raven).to receive(:extra_context).with(log_as_warning: true)

      expect { service.send(:request, :get, nil) }.to raise_error(
        Common::Client::Errors::HTTPError
      )
    end
  end
end
