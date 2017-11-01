require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  class TestConfiguration < Common::Client::Configuration::REST
    def base_path
      "http://127.0.0.1:9123/"
    end

    def connection
      @conn ||= Faraday.new(base_path) do |faraday|
        faraday.use(Common::Client::Middleware::Request::RemoveCookies)
        faraday.adapter :httpclient
      end
    end
  end

  class TestService < Common::Client::Base
    configuration TestConfiguration
  end

  describe '#request', run_at: '2017-01-04 03:00:00 EDT' do
    it 'should strip cookies' do
      VCR.config do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      server_thread = Thread.new do
        server = WEBrick::HTTPServer.new(
          Port: 9123
        )

        server.mount_proc '/' do |req, res|
          res.header['Set-Cookie'] = 'foo=bar'
          res.body = req.header.try(:[], 'cookie').to_json
        end

        server.start
      end

      Timeout::timeout(30) do
        while true
          begin
            if TestService.new.send(:request, :get, '', nil).status == 200
              break
            end
          rescue Common::Client::Errors::ClientError
          end
        end
      end

      expect(TestService.new.send(:request, :get, '', nil).body).to eq('[]')
    end
  end
end
