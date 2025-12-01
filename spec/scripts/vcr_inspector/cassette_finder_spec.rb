# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_inspector/cassette_finder'
require_relative '../../../script/vcr_inspector/cassette_parser'

RSpec.describe VcrInspector::CassetteFinder do
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  def default_cassette_content
    {
      'http_interactions' => [
        {
          'request' => { 'method' => 'get', 'uri' => 'https://example.com/api/test',
                         'body' => { 'string' => '' }, 'headers' => {} },
          'response' => { 'status' => { 'code' => 200, 'message' => 'OK' },
                          'body' => { 'string' => '{"data": "test"}' }, 'headers' => {} },
          'recorded_at' => Time.zone.now.strftime('%Y-%m-%dT%H:%M:%SZ')
        }
      ]
    }
  end

  def create_cassette(relative_path, content = nil)
    full_path = File.join(temp_dir, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, (content || default_cassette_content).to_yaml)
    full_path
  end

  describe '.all_cassettes' do
    it 'returns empty array for empty directory' do
      result = described_class.all_cassettes(temp_dir)
      expect(result).to eq([])
    end

    it 'finds yml files' do
      create_cassette('service1/test_cassette.yml')
      create_cassette('service2/another_cassette.yml')

      result = described_class.all_cassettes(temp_dir)

      expect(result.length).to eq(2)
      paths = result.map { |c| c[:path] }
      expect(paths).to include('service1/test_cassette')
      expect(paths).to include('service2/another_cassette')
    end

    it 'extracts service from path' do
      create_cassette('my_service/nested/cassette.yml')

      result = described_class.all_cassettes(temp_dir)

      expect(result.first[:service]).to eq('my_service')
    end

    it 'returns sorted by path' do
      create_cassette('z_service/cassette.yml')
      create_cassette('a_service/cassette.yml')

      result = described_class.all_cassettes(temp_dir)

      expect(result.first[:path]).to eq('a_service/cassette')
      expect(result.last[:path]).to eq('z_service/cassette')
    end
  end

  describe '.build_cassette_info' do
    it 'sets correct path' do
      file_path = create_cassette('test/my_cassette.yml')

      result = described_class.build_cassette_info(temp_dir, file_path)

      expect(result[:path]).to eq('test/my_cassette')
    end

    it 'sets correct name' do
      file_path = create_cassette('test/my_cassette.yml')

      result = described_class.build_cassette_info(temp_dir, file_path)

      expect(result[:name]).to eq('my_cassette')
    end

    it 'sets correct service' do
      file_path = create_cassette('my_service/my_cassette.yml')

      result = described_class.build_cassette_info(temp_dir, file_path)

      expect(result[:service]).to eq('my_service')
    end

    it 'sets full_path' do
      file_path = create_cassette('test/my_cassette.yml')

      result = described_class.build_cassette_info(temp_dir, file_path)

      expect(result[:full_path]).to eq(file_path)
    end

    it 'sets modified_at as Time' do
      file_path = create_cassette('test/my_cassette.yml')

      result = described_class.build_cassette_info(temp_dir, file_path)

      expect(result[:modified_at]).to be_a(Time)
    end
  end

  describe '.search' do
    it 'returns all when no query' do
      create_cassette('service1/cassette1.yml')
      create_cassette('service2/cassette2.yml')

      result = described_class.search(temp_dir, nil)

      expect(result.length).to eq(2)
    end

    it 'filters by query' do
      create_cassette('service1/matching_cassette.yml')
      create_cassette('service2/other_cassette.yml')

      result = described_class.search(temp_dir, 'matching')

      expect(result.length).to eq(1)
      expect(result.first[:path]).to eq('service1/matching_cassette')
    end

    it 'is case insensitive' do
      create_cassette('service1/TestCassette.yml')

      result = described_class.search(temp_dir, 'testcassette')

      expect(result.length).to eq(1)
    end

    it 'filters by service' do
      create_cassette('service1/cassette.yml')
      create_cassette('service2/cassette.yml')

      result = described_class.search(temp_dir, nil, { service: 'service1' })

      expect(result.length).to eq(1)
      expect(result.first[:service]).to eq('service1')
    end
  end

  describe '.apply_text_search' do
    it 'returns all for nil query' do
      cassettes = [{ path: 'test', name: 'test' }]
      result = described_class.apply_text_search(cassettes, nil)
      expect(result).to eq(cassettes)
    end

    it 'returns all for empty query' do
      cassettes = [{ path: 'test', name: 'test' }]
      result = described_class.apply_text_search(cassettes, '')
      expect(result).to eq(cassettes)
    end

    it 'matches path' do
      cassettes = [
        { path: 'matching/path', name: 'other' },
        { path: 'different/path', name: 'other' }
      ]
      result = described_class.apply_text_search(cassettes, 'matching')
      expect(result.length).to eq(1)
    end

    it 'matches name' do
      cassettes = [
        { path: 'path', name: 'matching_name' },
        { path: 'path', name: 'other_name' }
      ]
      result = described_class.apply_text_search(cassettes, 'matching')
      expect(result.length).to eq(1)
    end
  end

  describe '.apply_service_filter' do
    it 'returns all for nil service' do
      cassettes = [{ service: 'test' }]
      result = described_class.apply_service_filter(cassettes, nil)
      expect(result).to eq(cassettes)
    end

    it 'returns all for empty service' do
      cassettes = [{ service: 'test' }]
      result = described_class.apply_service_filter(cassettes, '')
      expect(result).to eq(cassettes)
    end

    it 'filters by service' do
      cassettes = [
        { service: 'service1' },
        { service: 'service2' }
      ]
      result = described_class.apply_service_filter(cassettes, 'service1')
      expect(result.length).to eq(1)
      expect(result.first[:service]).to eq('service1')
    end
  end

  describe '.group_by_service' do
    it 'counts correctly' do
      cassettes = [
        { service: 'service1' },
        { service: 'service1' },
        { service: 'service2' }
      ]

      result = described_class.group_by_service(cassettes)

      expect(result['service1']).to eq(2)
      expect(result['service2']).to eq(1)
    end

    it 'sorts by count descending' do
      cassettes = [
        { service: 'few' },
        { service: 'many' },
        { service: 'many' },
        { service: 'many' }
      ]

      result = described_class.group_by_service(cassettes)

      expect(result.keys.first).to eq('many')
      expect(result.keys.last).to eq('few')
    end
  end
end
