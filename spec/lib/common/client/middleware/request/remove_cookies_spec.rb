require 'rails_helper'

describe Common::Client::Middleware::Request::RemoveCookies do
  class TestConfiguration < Common::Client::Configuration::REST
    def base_path
      "http://127.0.0.1:3000/foos"
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
      # stub_request(:get, 'www.example.com/req1').to_return(headers: {
      #   'Set-Cookie' => 'foo=bar',
      #   'Connection' => 'close',
      #   'Cache-Control' => 'no-cache'
      # })

      # stub_request(:get, "www.example.com/req2").with(
        # headers: {
        #   # 'Cookie' => 'foo=bar',
        #   'User-Agent' => 'Faraday v0.9.2',
        #   'Accept' => '*/*',
        #   'Accept-Encoding' => 'gzip,deflate',
        #   'Date' => 'Wed, 04 Jan 2017 07:00:00 GMT'
        # }
      # ).to_return(body: 'bad')

      # # stub_request(:get, "www.example.com/req2").with(
      # #   headers: {
      # #     'User-Agent' => 'Faraday v0.9.2',
      # #     'Accept' => '*/*',
      # #     'Accept-Encoding' => 'gzip,deflate',
      # #     'Date' => 'Wed, 04 Jan 2017 07:00:00 GMT'
      # #   }
      # # ).to_return(body: 'good')

      # p TestService.new.send(:request, :get, '/req1', nil).body
      # p TestService.new.send(:request, :get, '/req2', nil).body

      # # match_requests_on: %i(method uri host path body headers)
      VCR.use_cassette('common/remove_cookies', record: :once, match_requests_on: %i(method uri host path body headers)) do
        TestService.new.send(:request, :get, '', nil)
        TestService.new.send(:request, :get, '', nil)
        # expect(WebMock).not_to have_requested(:get, 'http://127.0.0.1:3000/foos').with(headers: {
        #     # 'Cookie' => 'foo=bar',
        #     'User-Agent' => 'Faraday v0.9.2',
        #     'Accept' => '*/*',
        #     'Accept-Encoding' => 'gzip,deflate',
        #     'Date' => 'Wed, 04 Jan 2017 07:00:00 GMT'
        #   }
        # )
      end

      # stub_request(:get, "http://127.0.0.1:3000/foos").with(
      #   headers: {
      #     # 'Cookie' => 'foo=bar',
      #     'User-Agent' => 'Faraday v0.9.2',
      #     'Accept' => '*/*',
      #     'Accept-Encoding' => 'gzip,deflate',
      #     'Date' => 'Wed, 04 Jan 2017 07:00:00 GMT'
      #   }
      # ).to_return(body: 'bad')

      # p TestService.new.send(:request, :get, '', nil).body
    end
  end
end
