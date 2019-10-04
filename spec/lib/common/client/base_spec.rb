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
      end
    end
  end

  describe '#request' do
    it 'raises security error when http client is used without stripping cookies' do
      expect { Specs::Common::Client::TestService.new.send(:request, :get, '', nil) }.to raise_error(
        Common::Client::SecurityError
      )
    end
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'permanentlies set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'permanentlies set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'returns an empty hash' do
        empty_hash = {}

        Specs::Common::Client::TestService.new.send('sanitize_headers!', :request, :get, '', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end
end
