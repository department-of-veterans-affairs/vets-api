# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'

describe SM::Client::Attachments do
  let(:client) do
    client = SM::Client.new(session: { user_id: '10616687' })
    allow(client).to receive(:session).and_return(double(token: 'fake_token'))
    client
  end
  let(:message_id) { 629_999 }
  let(:attachment_id) { 629_993 }

  describe '#get_attachment' do
    it 'retrieves an attachment', :vcr do
      VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
        result = client.get_attachment(message_id, attachment_id)

        expect(result).to be_a(Hash)
        expect(result[:body]).to be_a(String)
        expect(result[:filename]).to eq('noise300x200.png')
      end
    end
  end

  describe '#stream_attachment' do
    let(:mock_config) { double(base_path: 'https://mhv-api.example.com/v1') }

    before do
      allow(client).to receive_messages(config: mock_config, token_headers: { 'Token' => 'fake_token' })
    end

    it 'streams a binary attachment directly from MHV' do
      # Mock the MHV API response as a binary attachment
      mock_mhv_response = double
      allow(mock_mhv_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_mhv_response).to receive(:[]).with('content-type').and_return('image/png')
      allow(mock_mhv_response).to receive(:[]).with('content-disposition').and_return('attachment; filename="test.png"')
      allow(mock_mhv_response).to receive(:[]).with('content-length').and_return('12345')
      allow(mock_mhv_response).to receive(:read_body).and_yield('chunk1').and_yield('chunk2')

      mock_http = double
      allow(mock_http).to receive(:request).and_yield(mock_mhv_response)
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      chunks = []
      headers_received = nil
      header_callback = lambda do |headers|
        headers_received = headers
      end

      client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
        chunks << chunk
      end

      expect(chunks).to eq(%w[chunk1 chunk2])
      expect(headers_received).not_to be_nil
      expect(headers_received.to_h['Content-Type']).to eq('image/png')
      expect(headers_received.to_h['Content-Disposition']).to include('test.png')
      expect(headers_received.to_h['Content-Length']).to eq('12345')
    end

    it 'streams an S3 attachment from presigned URL' do
      # Mock the MHV API response as JSON with S3 presigned URL
      s3_json = { data: { url: 'https://s3.amazonaws.com/test-bucket/test.pdf', mime_type: 'application/pdf', name: 'test.pdf' } }
      mock_mhv_response = double
      allow(mock_mhv_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_mhv_response).to receive(:[]).with('content-type').and_return('application/json')
      allow(mock_mhv_response).to receive(:read_body).and_return(s3_json.to_json)

      # Mock the S3 HTTP response
      mock_s3_response = double
      allow(mock_s3_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_s3_response).to receive(:[]).with('content-length').and_return('67890')
      allow(mock_s3_response).to receive(:read_body).and_yield('s3chunk1').and_yield('s3chunk2')

      mock_http = double
      # First call is to MHV, second is to S3
      call_count = 0
      allow(mock_http).to receive(:request) do |&block|
        call_count += 1
        block.call(call_count == 1 ? mock_mhv_response : mock_s3_response)
      end
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      chunks = []
      headers_received = nil
      header_callback = lambda do |headers|
        headers_received = headers
      end

      client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
        chunks << chunk
      end

      expect(chunks).to eq(%w[s3chunk1 s3chunk2])
      expect(headers_received.to_h['Content-Type']).to eq('application/pdf')
      expect(headers_received.to_h['Content-Disposition']).to include('test.pdf')
      expect(headers_received.to_h['Content-Length']).to eq('67890')
    end

    it 'raises error when MHV fetch fails' do
      mock_mhv_response = double(code: '500')
      allow(mock_mhv_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      mock_http = double
      allow(mock_http).to receive(:request).and_yield(mock_mhv_response)
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'raises RecordNotFound when attachment does not exist (MHV 404)' do
      mock_mhv_response = double(code: '404')
      allow(mock_mhv_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      mock_http = double
      allow(mock_http).to receive(:request).and_yield(mock_mhv_response)
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::RecordNotFound)
    end

    it 'raises error when S3 fetch fails' do
      # Mock the MHV API response as JSON with S3 presigned URL
      s3_json = { data: { url: 'https://s3.amazonaws.com/test-bucket/test.pdf', mime_type: 'application/pdf', name: 'test.pdf' } }
      mock_mhv_response = double
      allow(mock_mhv_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_mhv_response).to receive(:[]).with('content-type').and_return('application/json')
      allow(mock_mhv_response).to receive(:read_body).and_return(s3_json.to_json)

      # Mock the S3 HTTP response as failure
      mock_s3_response = double(code: '404')
      allow(mock_s3_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      mock_http = double
      call_count = 0
      allow(mock_http).to receive(:request) do |&block|
        call_count += 1
        block.call(call_count == 1 ? mock_mhv_response : mock_s3_response)
      end
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'handles network timeout errors gracefully' do
      allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout.new('Connection timed out'))

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'handles connection reset errors gracefully' do
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNRESET.new('Connection reset by peer'))

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'handles SSL errors gracefully' do
      allow(Net::HTTP).to receive(:start).and_raise(OpenSSL::SSL::SSLError.new('SSL handshake failed'))

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end
end
