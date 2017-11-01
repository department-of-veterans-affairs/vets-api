# frozen_string_literal: true
require 'rails_helper'

describe Common::Client::Base do
  class TestConfiguration2 < Common::Client::Configuration::REST
    def base_path
      'http://example.com'
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
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
end
