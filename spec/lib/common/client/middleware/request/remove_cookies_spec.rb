require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  class TestConfiguration < Common::Client::Configuration::REST
    def port
      3010
    end

    def base_path
      "http://127.0.0.1:#{port}"
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

  describe '#request' do
    let!(:server_thread) do
      Thread.new do
        server = WEBrick::HTTPServer.new(
          Port: TestConfiguration.instance.port
        )

        server.mount_proc '/' do |req, res|
          res.header['Set-Cookie'] = 'foo=bar'
          res.body = req.header.try(:[], 'cookie').to_json
        end

        server.start
      end
    end

    it 'should strip cookies' do
      VCR.configure do |c|
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
      VCR.configure do |c|
        c.allow_http_connections_when_no_cassette = false
      end

      server_thread.kill
    end
  end
end
