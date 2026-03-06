# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Idp::Client do
  describe '#initialize' do
    before do
      allow(Settings).to receive(:dig).and_call_original
    end

    it 'raises an error when base_url is not configured' do
      allow(Settings).to receive(:dig).with(:cave, :idp, :base_url).and_return(nil)
      allow(Settings).to receive(:dig).with(:cave, :idp, :timeout).and_return(nil)

      expect { described_class.new(base_url: nil) }
        .to raise_error(Idp::Error, /IDP base URL is not configured/)
    end

    it 'uses settings for base_url and timeout' do
      allow(Settings).to receive(:dig).with(:cave, :idp, :base_url).and_return('https://settings-idp.example.com')
      allow(Settings).to receive(:dig).with(:cave, :idp, :timeout).and_return(22)

      client = described_class.new

      expect(client.send(:base_url)).to eq('https://settings-idp.example.com')
      expect(client.send(:timeout)).to eq(22)
    end

    it 'uses the default timeout when none is provided' do
      client = described_class.new(base_url: 'https://example.com')

      expect(client.send(:timeout)).to eq(Idp::Client::DEFAULT_TIMEOUT)
    end

    it 'accepts a custom timeout' do
      client = described_class.new(base_url: 'https://example.com', timeout: 30)

      expect(client.send(:timeout)).to eq(30)
    end
  end

  describe 'IDP endpoints' do
    subject(:client) { described_class.new(base_url:, timeout:, hmac_key_id:, hmac_secret:) }

    let(:base_url) { 'https://idp.example.com' }
    let(:timeout) { 15 }
    let(:hmac_key_id) { 'idp-hmac-v1' }
    let(:hmac_secret) { 'super-secret' }
    let(:user_id) { 'user-account-uuid-123' }

    def valid_signed_headers?(request, user_id:, hmac_key_id:)
      headers = request.headers.transform_keys { |key| key.to_s.downcase }
      headers['x-idp-user-id'] == user_id &&
        headers['x-idp-key-id'] == hmac_key_id &&
        headers['x-idp-timestamp'].to_s.match?(/\A\d+\z/) &&
        headers['x-idp-signature'].to_s.match?(/\A[0-9a-f]{64}\z/)
    end

    def request_query(request)
      CGI.parse(URI.parse(request.uri.to_s).query.to_s).transform_values(&:first)
    end

    it 'sends intake request and returns parsed payload' do
      stub_request(:post, "#{base_url}/intake")
        .with(body: { pdf_b64: 'ZmlsZQ==' }.to_json)
        .to_return(status: 200, body: { id: 'abc123' }.to_json, headers: { 'Content-Type' => 'application/json' })

      response = client.intake(file_name: 'test.pdf', pdf_base64: 'ZmlsZQ==', user_id:)

      expect(response).to eq('id' => 'abc123')
      expect(WebMock).to have_requested(:post, "#{base_url}/intake").with { |request|
        request.headers['X-Filename'] == 'test.pdf' &&
          request.headers['Content-Type'].to_s.include?('application/json') &&
          valid_signed_headers?(request, user_id:, hmac_key_id:)
      }
    end

    it 'sends status request and returns parsed payload' do
      stub_request(:get, %r{#{Regexp.escape(base_url)}/status}).to_return(
        status: 200,
        body: { scan_status: 'completed' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      response = client.status('abc123', user_id:)

      expect(response).to eq('scan_status' => 'completed')
      expect(WebMock).to have_requested(:get, %r{#{Regexp.escape(base_url)}/status}).with { |request|
        request_query(request) == { 'id' => 'abc123' } &&
          valid_signed_headers?(request, user_id:, hmac_key_id:)
      }
    end

    it 'sends output request and returns parsed payload' do
      stub_request(:get, %r{#{Regexp.escape(base_url)}/output}).to_return(
        status: 200,
        body: { forms: [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      response = client.output('abc123', type: 'artifact', user_id:)

      expect(response).to eq('forms' => [])
      expect(WebMock).to have_requested(:get, %r{#{Regexp.escape(base_url)}/output}).with { |request|
        request_query(request) == { 'id' => 'abc123', 'type' => 'artifact' } &&
          valid_signed_headers?(request, user_id:, hmac_key_id:)
      }
    end

    it 'sends download request and returns parsed payload' do
      stub_request(:get, %r{#{Regexp.escape(base_url)}/download}).to_return(
        status: 200,
        body: { data: { foo: 'bar' } }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

      response = client.download('abc123', kvpid: 'kvp1', user_id:)

      expect(response).to eq('data' => { 'foo' => 'bar' })
      expect(WebMock).to have_requested(:get, %r{#{Regexp.escape(base_url)}/download}).with { |request|
        request_query(request) == { 'id' => 'abc123', 'kvpid' => 'kvp1' } &&
          valid_signed_headers?(request, user_id:, hmac_key_id:)
      }
    end

    it 'sends update request and returns parsed payload' do
      expected_payload = { FIRST_NAME: 'Ada', LAST_NAME: 'Lovelace' }.to_json
      stub_request(:post, %r{#{Regexp.escape(base_url)}/update}).to_return(
        status: 200,
        body: expected_payload,
        headers: { 'Content-Type' => 'application/json' }
      )

      response = client.update(
        'abc123',
        kvpid: 'kvp1',
        payload: { FIRST_NAME: 'Ada', LAST_NAME: 'Lovelace' },
        user_id:
      )

      expect(response).to eq('FIRST_NAME' => 'Ada', 'LAST_NAME' => 'Lovelace')
      expect(WebMock).to have_requested(:post, %r{#{Regexp.escape(base_url)}/update}).with { |request|
        request_query(request) == { 'id' => 'abc123', 'kvpid' => 'kvp1' } &&
          request.body == expected_payload &&
          request.headers['Content-Type'].to_s.include?('application/json') &&
          valid_signed_headers?(request, user_id:, hmac_key_id:)
      }
    end

    it 'raises an error when user identity is missing' do
      expect { client.status('abc123', user_id: nil) }.to raise_error(Idp::Error, /user identity is required/)
    end

    it 'raises Idp::Error for timeouts' do
      stub_request(:get, "#{base_url}/status").with(query: { id: 'abc123' }).to_timeout

      expect { client.status('abc123', user_id:) }.to raise_error(Idp::Error)
    end

    it 'raises Idp::Error for 5xx responses' do
      stub_request(:get, "#{base_url}/download")
        .with(query: { id: 'abc123', kvpid: 'kvp1' })
        .to_return(status: 500, body: { error: 'upstream error' }.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect { client.download('abc123', kvpid: 'kvp1', user_id:) }.to raise_error(Idp::Error, /500/)
    end
  end
end
