require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  class TestConfiguration < Common::Client::Configuration::REST
    def base_path
      # TODO see if this is a good port
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
    let!(:server_thread) do
      Thread.new do
        server = WEBrick::HTTPServer.new(
          Port: 9123
        )

        server.mount_proc '/' do |req, res|
          res.header['Set-Cookie'] = 'foo=bar'
          res.body = req.header.try(:[], 'cookie').to_json
        end

        server.start
      end
    end

    it 'should strip cookies' do
      VCR.config do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      Timeout::timeout(5) do
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

    after do
      VCR.config do |c|
        c.allow_http_connections_when_no_cassette = false
      end

      server_thread.kill
    end
  end
end
