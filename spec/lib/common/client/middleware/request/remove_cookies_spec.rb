# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  module Specs
    module RemoveCookies
      class TestConfiguration < ::Common::Client::Configuration::REST
        def port
          3010
        end

        def service_name
          'TestClient'
        end

        def connection
          @conn ||= Faraday.new("http://127.0.0.1:#{port}") do |faraday|
            faraday.use :breakers
            faraday.use :remove_cookies
            faraday.adapter :httpclient
          end
        end
      end

      class TestService < ::Common::Client::Base
        configuration TestConfiguration
      end
    end
  end

  describe '#request' do
    let!(:server_thread) do
      Thread.new do
        dev_null = WEBrick::Log.new('/dev/null', 7) # suppress logging to $stdout

        server = WEBrick::HTTPServer.new(
          Port: Specs::RemoveCookies::TestConfiguration.instance.port,
          Logger: dev_null,
          AccessLog: dev_null
        )

        server.mount_proc '/' do |req, res|
          res.cookies << WEBrick::Cookie.new('foo', 'bar')
          res.body = req.cookies.to_json
        end

        server.start
      end
    end

    after do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = false
      end

      server_thread.kill
    end

    it 'strips cookies' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      Timeout.timeout(5) do
        loop do
          begin
            break if Specs::RemoveCookies::TestService.new.send(:request, :get, '', nil).status == 200
          rescue Common::Client::Errors::ClientError
            next
          end
        end
      end

      expect(Specs::RemoveCookies::TestService.new.send(:request, :get, '', nil).body).to eq('[]')
    end
  end
end
