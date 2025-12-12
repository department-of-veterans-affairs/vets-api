# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_mcp/service_config'

RSpec.describe VcrMcp::ServiceConfig do
  before { described_class.reset_cache! }
  after { described_class.reset_cache! }

  describe '.detect_by_placeholders' do
    it 'returns nil for nil interactions' do
      result = described_class.send(:detect_by_placeholders, nil)
      expect(result).to be_nil
    end

    it 'returns nil for empty interactions' do
      result = described_class.send(:detect_by_placeholders, [])
      expect(result).to be_nil
    end

    it 'returns nil for interactions without URIs' do
      interactions = [
        { request: { method: 'GET' } },
        { request: { body: 'test' } }
      ]
      result = described_class.send(:detect_by_placeholders, interactions)
      expect(result).to be_nil
    end
  end

  describe '.detect_from_cassette' do
    it 'returns nil with empty interactions' do
      result = described_class.detect_from_cassette('test/cassette', [])
      expect(result).to be_nil
    end

    it 'returns nil with nil interactions' do
      result = described_class.detect_from_cassette('test/cassette', nil)
      expect(result).to be_nil
    end
  end

  describe '.build_service_result' do
    it 'returns nil for nil namespace' do
      result = described_class.send(:build_service_result, nil)
      expect(result).to be_nil
    end
  end

  describe '.humanize_namespace' do
    it 'converts dots to spaces and uppercases' do
      result = described_class.send(:humanize_namespace, 'mhv.uhd')
      expect(result).to eq('MHV UHD')
    end

    it 'converts underscores to spaces' do
      result = described_class.send(:humanize_namespace, 'mhv.api_gateway')
      expect(result).to eq('MHV API GATEWAY')
    end

    it 'handles single segment' do
      result = described_class.send(:humanize_namespace, 'lighthouse')
      expect(result).to eq('LIGHTHOUSE')
    end
  end

  describe '.assign_port' do
    it 'returns integer in valid range' do
      port = described_class.send(:assign_port, 'test_service')

      expect(port).to be_a(Integer)
      expect(port).to be >= described_class::PORT_RANGE_START
      expect(port).to be <= described_class::PORT_RANGE_END
    end

    it 'returns consistent port for same identifier' do
      port1 = described_class.send(:assign_port, 'mhv.sm')
      port2 = described_class.send(:assign_port, 'mhv.sm')

      expect(port1).to eq(port2)
    end

    it 'returns valid ports for different identifiers' do
      port1 = described_class.send(:assign_port, 'mhv.sm')
      port2 = described_class.send(:assign_port, 'lighthouse')

      expect(port1).to be >= described_class::PORT_RANGE_START
      expect(port2).to be >= described_class::PORT_RANGE_START
    end
  end

  describe '.reset_cache!' do
    it 'clears cached data' do
      described_class.reset_cache!
      expect(described_class::CACHE).to be_empty
    end
  end

  describe '.settings_namespace_from_path' do
    it 'extracts namespace by removing last segment' do
      result = described_class.send(:settings_namespace_from_path, 'mhv.sm.host')
      expect(result).to eq('mhv.sm')
    end

    it 'returns path as-is for single segment' do
      result = described_class.send(:settings_namespace_from_path, 'host')
      expect(result).to eq('host')
    end

    it 'handles hosts special case for sm paths' do
      result = described_class.send(:settings_namespace_from_path, 'mhv.api_gateway.hosts.sm_patient')
      expect(result).to eq('mhv.sm')
    end

    it 'removes last segment for multi-segment paths' do
      result = described_class.send(:settings_namespace_from_path, 'lighthouse.health.host')
      expect(result).to eq('lighthouse.health')
    end
  end

  describe '.extract_placeholders_from_content' do
    it 'extracts Settings-based placeholders' do
      content = <<~RUBY
        VCR.configure do |c|
          c.filter_sensitive_data('<MHV_SM_HOST>') { Settings.mhv.sm.host }
          c.filter_sensitive_data('<OTHER_HOST>') { Settings.other.host }
        end
      RUBY

      result = described_class.send(:extract_placeholders_from_content, content)

      expect(result).to be_a(Hash)
      expect(result['MHV_SM_HOST']).to eq('mhv.sm.host')
      expect(result['OTHER_HOST']).to eq('other.host')
    end

    it 'ignores non-Settings placeholders' do
      content = <<~RUBY
        VCR.configure do |c|
          c.filter_sensitive_data('<TOKEN>') { some_other_method }
        end
      RUBY

      result = described_class.send(:extract_placeholders_from_content, content)

      expect(result).to be_a(Hash)
      expect(result).not_to have_key('TOKEN')
    end

    it 'handles empty content' do
      result = described_class.send(:extract_placeholders_from_content, '')
      expect(result).to eq({})
    end
  end

  describe 'caching without deadlock' do
    # Regression test for recursive locking issue
    # Previously, calling placeholder_to_namespace would deadlock because
    # it called cached_fetch, which then called parse_vcr_placeholders
    # inside the block, which also called cached_fetch with the same lock

    it 'does not deadlock when calling placeholder_to_namespace' do
      # This would previously raise: deadlock; recursive locking
      expect { described_class.placeholder_to_namespace }.not_to raise_error
    end

    it 'does not deadlock when calling namespaces_to_placeholders' do
      # This depends on placeholder_to_namespace, which depends on parse_vcr_placeholders
      expect { described_class.namespaces_to_placeholders }.not_to raise_error
    end

    it 'does not deadlock when calling detect_from_cassette with placeholder URIs' do
      interactions = [
        { request: { uri: 'https://<MHV_SM_HOST>/api/v1/messages' } }
      ]
      # This calls placeholder_to_namespace internally
      expect { described_class.detect_from_cassette('test/cassette', interactions) }.not_to raise_error
    end

    it 'caches results correctly across multiple calls' do
      # First call populates cache
      result1 = described_class.placeholder_to_namespace
      # Second call should use cache
      result2 = described_class.placeholder_to_namespace

      expect(result1).to eq(result2)
    end

    it 'allows sequential access to dependent cached methods' do
      # These methods have dependencies:
      # namespaces_to_placeholders -> placeholder_to_namespace -> parse_vcr_placeholders
      # Ensure they can all be called in sequence without deadlock
      expect { described_class.parse_vcr_placeholders }.not_to raise_error
      expect { described_class.placeholder_to_namespace }.not_to raise_error
      expect { described_class.namespaces_to_placeholders }.not_to raise_error
    end
  end
end
