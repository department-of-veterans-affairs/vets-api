# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_mcp/ssl_patcher'

RSpec.describe VcrMcp::SslPatcher do
  let(:vets_api_root) { VcrMcp::Constants::VETS_API_ROOT }
  let(:patcher) { described_class.new }

  describe '#resolve_path (private)' do
    # We test the private method directly since it's the security-critical component
    subject(:resolve_path) { patcher.send(:resolve_path, path) }

    context 'with valid paths within VETS_API_ROOT' do
      let(:path) { 'lib/sm/configuration.rb' }

      it 'resolves relative paths to VETS_API_ROOT' do
        expect(resolve_path).to eq(File.join(vets_api_root, 'lib/sm/configuration.rb'))
      end
    end

    context 'with absolute paths within VETS_API_ROOT' do
      let(:path) { File.join(vets_api_root, 'lib/rx/configuration.rb') }

      it 'accepts absolute paths within VETS_API_ROOT' do
        expect(resolve_path).to eq(path)
      end
    end

    context 'with path traversal attempts' do
      it 'raises error for absolute paths outside VETS_API_ROOT' do
        expect { patcher.send(:resolve_path, '/etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'raises error for relative path traversal with ../' do
        expect { patcher.send(:resolve_path, '../../../etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'raises error for path traversal to parent directories' do
        expect { patcher.send(:resolve_path, '../../some_other_repo/config.rb') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'raises error for traversal that tries to escape and return' do
        expect { patcher.send(:resolve_path, '../../../Users/../etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'handles tilde paths as literal characters (not home expansion)' do
        # When File.expand_path is given a base path, ~ is treated literally
        # This stays within VETS_API_ROOT as a literal path segment
        result = patcher.send(:resolve_path, '~/.ssh/id_rsa')
        expect(result).to start_with(vets_api_root)
        expect(result).to include('~')
      end
    end

    context 'with edge cases' do
      it 'handles paths with redundant slashes' do
        path = 'lib//sm///configuration.rb'
        expect(patcher.send(:resolve_path, path)).to eq(File.join(vets_api_root, 'lib/sm/configuration.rb'))
      end

      it 'handles paths starting with ./' do
        path = './lib/sm/configuration.rb'
        expect(patcher.send(:resolve_path, path)).to eq(File.join(vets_api_root, 'lib/sm/configuration.rb'))
      end

      it 'normalizes paths with internal ../ that stay within root' do
        path = 'lib/sm/../rx/configuration.rb'
        expect(patcher.send(:resolve_path, path)).to eq(File.join(vets_api_root, 'lib/rx/configuration.rb'))
      end
    end
  end

  describe '.patch_file' do
    context 'with path traversal attempts' do
      it 'raises error when trying to patch files outside VETS_API_ROOT' do
        expect { described_class.patch_file('/etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'raises error for relative path traversal' do
        expect { described_class.patch_file('../../../etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end
    end

    context 'with non-existent files within VETS_API_ROOT' do
      it 'returns error hash for non-existent file' do
        result = described_class.patch_file('lib/nonexistent/file.rb')
        expect(result).to have_key(:error)
        expect(result[:error]).to include('File not found')
      end
    end
  end

  describe '.unpatch_file' do
    context 'with path traversal attempts' do
      it 'raises error when trying to unpatch files outside VETS_API_ROOT' do
        expect { described_class.unpatch_file('/etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end

      it 'raises error for relative path traversal' do
        expect { described_class.unpatch_file('../../../etc/passwd') }
          .to raise_error(ArgumentError, /resolves outside the vets-api directory/)
      end
    end

    context 'with non-existent files within VETS_API_ROOT' do
      it 'returns error hash for file without backup or patch' do
        result = described_class.unpatch_file('lib/nonexistent/file.rb')
        expect(result).to have_key(:error)
        expect(result[:error]).to include('No backup or patch found')
      end
    end
  end

  describe '.list_patched_files' do
    it 'returns a hash with files and count keys' do
      result = described_class.list_patched_files
      expect(result).to have_key(:files)
      expect(result).to have_key(:count)
      expect(result[:files]).to be_an(Array)
      expect(result[:count]).to be_an(Integer)
    end
  end

  describe '.unpatch_all' do
    it 'returns a hash with unpatched and errors keys' do
      result = described_class.unpatch_all
      expect(result).to have_key(:unpatched)
      expect(result).to have_key(:errors)
      expect(result[:unpatched]).to be_an(Array)
      expect(result[:errors]).to be_an(Array)
    end
  end

  describe 'SSL_DISABLE_MARKER constants' do
    it 'has start and end markers defined' do
      expect(described_class::SSL_DISABLE_MARKER).to eq('# VCR_SSL_PATCH_START')
      expect(described_class::SSL_DISABLE_END_MARKER).to eq('# VCR_SSL_PATCH_END')
    end
  end
end
