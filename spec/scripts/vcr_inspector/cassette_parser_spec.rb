# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_inspector/cassette_parser'

RSpec.describe VcrInspector::CassetteParser do
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  def create_cassette_file(content)
    file_path = File.join(temp_dir, 'test_cassette.yml')
    File.write(file_path, content.to_yaml)
    file_path
  end

  def sample_cassette_content
    {
      'http_interactions' => [sample_interaction],
      'recorded_with' => 'VCR 6.0.0'
    }
  end

  def sample_interaction
    {
      'request' => {
        'method' => 'get',
        'uri' => 'https://api.example.com/v1/resource',
        'body' => { 'string' => '' },
        'headers' => { 'Accept' => ['application/json'] }
      },
      'response' => {
        'status' => { 'code' => 200, 'message' => 'OK' },
        'body' => { 'string' => '{"data": "test"}' },
        'headers' => { 'Content-Type' => ['application/json'] }
      },
      'recorded_at' => '2024-06-15T10:00:00Z'
    }
  end

  describe '.parse' do
    it 'returns interactions and raw' do
      cassette_path = create_cassette_file(sample_cassette_content)

      result = described_class.parse(cassette_path)

      expect(result).to have_key(:interactions)
      expect(result).to have_key(:raw)
    end

    it 'extracts interactions' do
      cassette_path = create_cassette_file(sample_cassette_content)

      result = described_class.parse(cassette_path)

      expect(result[:interactions].length).to eq(1)
    end

    it 'handles missing file' do
      result = described_class.parse('/nonexistent/file.yml')

      expect(result).to have_key(:error)
    end
  end

  describe '.parse_interactions' do
    it 'returns empty array for nil' do
      result = described_class.parse_interactions(nil)
      expect(result).to eq([])
    end

    it 'extracts request and response' do
      interactions = [sample_interaction]

      result = described_class.parse_interactions(interactions)

      expect(result.first).to have_key(:request)
      expect(result.first).to have_key(:response)
      expect(result.first).to have_key(:recorded_at)
    end
  end

  describe '.parse_request' do
    it 'extracts method' do
      request = { 'method' => 'post', 'uri' => 'http://test.com', 'body' => {}, 'headers' => {} }

      result = described_class.parse_request(request)

      expect(result[:method]).to eq('post')
    end

    it 'extracts uri' do
      request = { 'method' => 'get', 'uri' => 'http://example.com/api', 'body' => {}, 'headers' => {} }

      result = described_class.parse_request(request)

      expect(result[:uri]).to eq('http://example.com/api')
    end

    it 'extracts headers' do
      headers = { 'Content-Type' => ['application/json'] }
      request = { 'method' => 'get', 'uri' => 'http://test.com', 'body' => {}, 'headers' => headers }

      result = described_class.parse_request(request)

      expect(result[:headers]).to eq(headers)
    end

    it 'handles missing headers' do
      request = { 'method' => 'get', 'uri' => 'http://test.com', 'body' => {} }

      result = described_class.parse_request(request)

      expect(result[:headers]).to eq({})
    end
  end

  describe '.parse_response' do
    it 'extracts status code' do
      response = {
        'status' => { 'code' => 200, 'message' => 'OK' },
        'body' => {},
        'headers' => {}
      }

      result = described_class.parse_response(response)

      expect(result[:status][:code]).to eq(200)
    end

    it 'extracts status message' do
      response = {
        'status' => { 'code' => 404, 'message' => 'Not Found' },
        'body' => {},
        'headers' => {}
      }

      result = described_class.parse_response(response)

      expect(result[:status][:message]).to eq('Not Found')
    end
  end

  describe '.parse_body' do
    it 'returns nil for nil body' do
      result = described_class.parse_body(nil)
      expect(result).to be_nil
    end

    it 'parses JSON body' do
      body = { 'string' => '{"key": "value"}' }

      result = described_class.parse_body(body)

      expect(result[:is_json]).to be(true)
      expect(result[:json]).to eq({ 'key' => 'value' })
    end

    it 'handles non-JSON body' do
      body = { 'string' => 'plain text response' }

      result = described_class.parse_body(body)

      expect(result[:is_json]).to be(false)
      expect(result[:raw]).to eq('plain text response')
    end

    it 'handles empty string' do
      body = { 'string' => '' }

      result = described_class.parse_body(body)

      expect(result[:is_json]).to be(false)
    end
  end

  describe '.detect_image_type' do
    it 'detects PNG' do
      png_header = "\x89PNG\r\n\x1a\n"
      result = described_class.detect_image_type(png_header)
      expect(result).to eq('png')
    end

    it 'detects JPEG' do
      jpeg_header = "\xFF\xD8\xFF"
      result = described_class.detect_image_type(jpeg_header)
      expect(result).to eq('jpeg')
    end

    it 'detects GIF' do
      gif_header = 'GIF89a'
      result = described_class.detect_image_type(gif_header)
      expect(result).to eq('gif')
    end

    it 'returns nil for unknown' do
      result = described_class.detect_image_type('not an image')
      expect(result).to be_nil
    end
  end
end
