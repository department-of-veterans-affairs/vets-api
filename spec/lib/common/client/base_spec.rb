require 'rails_helper'

describe Common::Client::Base do
  class TestConfiguration < Common::Client::Configuration::REST
    def base_path
      "http://example.com"
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.adapter :httpclient
      end
    end
  end

  class TestService < Common::Client::Base
    configuration TestConfiguration
  end

  describe '#request' do
    it 'should raise security error when http client is used without stripping cookies' do
      expect { TestService.new.send(:request, :get, '', nil) }.to raise_error(Common::Client::SecurityError)
    end
  end
end
