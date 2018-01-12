# frozen_string_literal: true
require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  class TestConfiguration < Common::Client::Configuration::REST
    def port
      3010
    end

    def connection
      @conn ||= Faraday.new("http://127.0.0.1:#{port}") do |faraday|
        faraday.use :remove_cookies
        faraday.adapter :httpclient
      end
    end
  end

  class TestService < Common::Client::Base
    configuration TestConfiguration
  end

  describe '#request' do
    let!(:server_thread) do
      Thread.new do
        server = WEBrick::HTTPServer.new(
          Logger: WEBrick::Log.new(File.open(File::NULL, 'w')),
          Port: TestConfiguration.instance.port
        )

        server.mount_proc '/' do |req, res|
          res.cookies << WEBrick::Cookie.new('foo', 'bar')
          res.body = req.cookies.to_json
        end

        server.start
      end
    end

    it 'should strip cookies' do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      Timeout.timeout(5) do
        loop do
          begin
            break if TestService.new.send(:request, :get, '', nil).status == 200
          rescue Common::Client::Errors::ClientError
            next
          end
        end
      end

      expect(TestService.new.send(:request, :get, '', nil).body).to eq('[]')
    end

    after do
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = false
      end

      server_thread.kill
    end
  end
end
