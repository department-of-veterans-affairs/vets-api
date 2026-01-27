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
    it 'streams an attachment in chunks' do
      # Mock the response from MHV API
      mock_response = double(
        body: 'fake binary data',
        response_headers: {
          'content-type' => 'image/png',
          'content-disposition' => 'attachment; filename="test.png"'
        }
      )
      allow(client).to receive(:perform).and_return(mock_response)

      chunks = []
      headers_received = nil
      header_callback = lambda do |headers|
        headers_received = headers
      end

      client.stream_attachment(message_id, attachment_id, header_callback) do |chunk|
        chunks << chunk
      end

      expect(chunks).not_to be_empty
      expect(chunks.join).to eq('fake binary data')
      expect(headers_received).not_to be_nil
      expect(headers_received.to_h['Content-Type']).to eq('image/png')
    end

    it 'streams an S3 attachment from presigned URL' do
      # Mock the response with S3 presigned URL format
      mock_mhv_response = double(
        body: {
          data: {
            url: 'https://s3.amazonaws.com/test-bucket/test.pdf',
            mime_type: 'application/pdf',
            name: 'test.pdf'
          }
        },
        response_headers: {}
      )
      allow(client).to receive(:perform).and_return(mock_mhv_response)

      # Mock the S3 HTTP response
      mock_http_response = double
      allow(mock_http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(mock_http_response).to receive(:read_body).and_yield('chunk1').and_yield('chunk2')

      mock_http = double
      allow(mock_http).to receive(:request).and_yield(mock_http_response)
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
      expect(headers_received.to_h['Content-Type']).to eq('application/pdf')
      expect(headers_received.to_h['Content-Disposition']).to include('test.pdf')
    end

    it 'raises error when S3 fetch fails' do
      # Mock the response with S3 presigned URL format
      mock_mhv_response = double(
        body: {
          data: {
            url: 'https://s3.amazonaws.com/test-bucket/test.pdf',
            mime_type: 'application/pdf',
            name: 'test.pdf'
          }
        },
        response_headers: {}
      )
      allow(client).to receive(:perform).and_return(mock_mhv_response)

      # Mock the S3 HTTP response as failure
      mock_http_response = double(code: '404')
      allow(mock_http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      mock_http = double
      allow(mock_http).to receive(:request).and_yield(mock_http_response)
      allow(Net::HTTP).to receive(:start).and_yield(mock_http)

      header_callback = ->(_headers) {}

      expect do
        client.stream_attachment(message_id, attachment_id, header_callback) { |_chunk| }
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end
end
