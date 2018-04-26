# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Base do
  class TestConfiguration2 < Common::Client::Configuration::REST
    def connection
      @conn ||= Faraday.new('http://example.com') do |faraday|
        faraday.adapter :httpclient
      end
    end
  end

  class TestService2 < Common::Client::Base
    configuration TestConfiguration2
  end

  describe '#request' do
    it 'should raise security error when http client is used without stripping cookies' do
      expect { TestService2.new.send(:request, :get, '', nil) }.to raise_error(Common::Client::SecurityError)
    end
  end

  describe '#sanitize_headers!' do
    context 'where headers have symbol hash keys' do
      it 'should permanently set any nil values to an empty string' do
        symbolized_hash = { foo: nil, bar: 'baz' }

        TestService2.new.send('sanitize_headers!', symbolized_hash)

        expect(symbolized_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where headers have string hash keys' do
      it 'should permanently set any nil values to an empty string' do
        string_hash = { 'foo' => nil, 'bar' => 'baz' }

        TestService2.new.send('sanitize_headers!', string_hash)

        expect(string_hash).to eq('foo' => '', 'bar' => 'baz')
      end
    end

    context 'where header is an empty hash' do
      it 'should return an empty hash' do
        empty_hash = {}

        TestService2.new.send('sanitize_headers!', empty_hash)

        expect(empty_hash).to eq({})
      end
    end
  end
end
