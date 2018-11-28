# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Base do
  class Common::Client::Base::TestConfiguration < Common::Client::Configuration::REST
    def connection
      Faraday.new('http://example.com') do |faraday|
        faraday.adapter :httpclient
      end
    end

    def service_name
      'test_service'
    end
  end

  class Common::Client::Base::TestService < Common::Client::Base
    configuration Common::Client::Base::TestConfiguration
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'should permanently set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'should permanently set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'should return an empty hash' do
        empty_hash = {}

        Common::Client::Base::TestService.new.send('sanitize_headers!', :request, :get, '', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end
end
