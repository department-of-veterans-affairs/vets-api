# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_mcp/inspector'

RSpec.describe VcrMcp::Inspector do
  describe '.resolve_safe_path' do
    let(:cassette_root) { VcrMcp::Constants::CASSETTE_ROOT }

    context 'with valid paths within CASSETTE_ROOT' do
      it 'resolves a simple filename' do
        result = described_class.resolve_safe_path('test_cassette.yml')
        expect(result).to eq(File.join(cassette_root, 'test_cassette.yml'))
      end

      it 'resolves a nested path' do
        result = described_class.resolve_safe_path('sm_client/messages/get_message.yml')
        expect(result).to eq(File.join(cassette_root, 'sm_client/messages/get_message.yml'))
      end

      it 'normalizes paths with redundant slashes' do
        result = described_class.resolve_safe_path('sm_client//messages///get_message.yml')
        expect(result).to eq(File.join(cassette_root, 'sm_client/messages/get_message.yml'))
      end
    end

    context 'with path traversal attempts' do
      it 'rejects absolute paths outside CASSETTE_ROOT' do
        result = described_class.resolve_safe_path('/etc/passwd')
        expect(result).to be_nil
      end

      it 'rejects relative path traversal with ../' do
        result = described_class.resolve_safe_path('../../../etc/passwd')
        expect(result).to be_nil
      end

      it 'rejects path traversal to config directory' do
        result = described_class.resolve_safe_path('../../config/database.yml')
        expect(result).to be_nil
      end

      it 'rejects path traversal to settings file' do
        result = described_class.resolve_safe_path('../../../config/settings.local.yml')
        expect(result).to be_nil
      end

      it 'rejects path traversal with encoded characters' do
        # Even if someone tries URL-encoded traversal, File.expand_path handles it
        result = described_class.resolve_safe_path('..%2F..%2F..%2Fetc/passwd')
        # This stays within cassette root because %2F is not decoded by File.expand_path
        expect(result).to start_with(cassette_root)
      end

      it 'rejects traversal that tries to escape and come back' do
        result = described_class.resolve_safe_path('../../../spec/support/vcr_cassettes/../../../etc/passwd')
        expect(result).to be_nil
      end
    end

    context 'with edge cases' do
      it 'handles empty string' do
        result = described_class.resolve_safe_path('')
        expect(result).to eq(cassette_root)
      end

      it 'handles path with only dots' do
        result = described_class.resolve_safe_path('...')
        expect(result).to eq(File.join(cassette_root, '...'))
      end

      it 'handles path starting with ./' do
        result = described_class.resolve_safe_path('./test_cassette.yml')
        expect(result).to eq(File.join(cassette_root, 'test_cassette.yml'))
      end
    end
  end

  describe '.find_cassette' do
    let(:cassette_root) { VcrMcp::Constants::CASSETTE_ROOT }

    context 'with path traversal attempts' do
      it 'returns nil for absolute paths outside CASSETTE_ROOT' do
        result = described_class.find_cassette('/etc/passwd')
        expect(result).to be_nil
      end

      it 'returns nil for relative path traversal' do
        result = described_class.find_cassette('../../../etc/passwd')
        expect(result).to be_nil
      end

      it 'returns nil for traversal to sensitive config files' do
        result = described_class.find_cassette('../../config/database.yml')
        expect(result).to be_nil
      end

      it 'does not allow reading files outside cassette directory even if they exist' do
        # config/application.rb definitely exists in the repo
        result = described_class.find_cassette('../../../config/application.rb')
        expect(result).to be_nil
      end
    end

    context 'with valid cassette queries' do
      it 'finds an existing cassette by full path' do
        # Use a cassette that should exist in the repo
        cassettes = Dir.glob(File.join(cassette_root, '**/*.yml')).first(1)
        skip 'No cassettes found in repository' if cassettes.empty?

        cassette_path = cassettes.first
        relative_path = cassette_path.sub("#{cassette_root}/", '')

        result = described_class.find_cassette(relative_path)
        expect(result).to eq(cassette_path)
      end

      it 'finds a cassette without .yml extension' do
        cassettes = Dir.glob(File.join(cassette_root, '**/*.yml')).first(1)
        skip 'No cassettes found in repository' if cassettes.empty?

        cassette_path = cassettes.first
        relative_path = cassette_path.sub("#{cassette_root}/", '').sub(/\.yml$/, '')

        result = described_class.find_cassette(relative_path)
        expect(result).to eq(cassette_path)
      end

      it 'returns nil for non-existent cassette' do
        result = described_class.find_cassette('this_cassette_definitely_does_not_exist_12345')
        expect(result).to be_nil
      end
    end

    context 'with search functionality' do
      it 'uses only basename for glob search to prevent path injection' do
        # Even if query contains path traversal, search should use only the basename
        # This shouldn't find anything because 'passwd' is not a cassette name
        result = described_class.find_cassette('../../../etc/passwd')
        expect(result).to be_nil
      end
    end
  end

  describe '.inspect' do
    context 'with path traversal attempts' do
      it 'returns error for paths outside CASSETTE_ROOT' do
        result = described_class.inspect('/etc/passwd')
        expect(result).to have_key(:error)
        expect(result[:error]).to include('No cassette found')
      end

      it 'returns error for relative path traversal' do
        result = described_class.inspect('../../../config/database.yml')
        expect(result).to have_key(:error)
        expect(result[:error]).to include('No cassette found')
      end
    end
  end
end
