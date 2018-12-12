# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Base do
  module Specs
    module Common
      module Client
        class TestConfiguration < ::Common::Client::Configuration::REST
          def connection
            @conn ||= Faraday.new('http://example.com') do |faraday|
              faraday.adapter :httpclient
            end
          end
        end

        class TestService < ::Common::Client::Base
          configuration TestConfiguration
        end

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
        end
      end
    end
  end

  describe '#request' do
    it 'should raise security error when http client is used without stripping cookies' do
      expect { Specs::Common::Client::TestService.new.send(:request, :get, '', nil) }.to raise_error(
        Common::Client::SecurityError
      )
    end

    context 'service unavailable errors' do
      let(:service) { Specs::Common::Client::DefaultService.new }

      context 'when request raises a 503 backend service exception' do
        it 'should raise a ServiceUnavailable error' do
          expect(service).to receive(:connection).and_raise(
            Common::Exceptions::BackendServiceException.new(nil, {}, 503)
          )
          expect { service.send(:request, :get, nil) }.to raise_error(
            Common::Exceptions::ServiceUnavailable
          )
        end
      end

      context 'when a request raises a 503 HTTPError error' do
        it 'should raise a ServiceUnavailable error' do
          expect(service).to receive(:connection).and_raise(Common::Client::Errors::HTTPError.new(nil, 503))
          expect { service.send(:request, :get, nil) }.to raise_error(
            Common::Exceptions::ServiceUnavailable
          )
        end
      end
    end
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'should permanently set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'should permanently set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'should return an empty hash' do
        empty_hash = {}

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end
end
