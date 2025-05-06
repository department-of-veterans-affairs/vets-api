# frozen_string_literal: true

require 'rails_helper'
require 'sftp_writer/remote'

RSpec.describe SFTPWriter::Remote do
  describe '#close' do
    it 'returns if sftp has not started' do
      expect(described_class.new({}, logger: {}).close).to be_nil
    end
  end

  describe '#sanitize' do
    it 'returns a filename without colons' do
      result = described_class.new({}, logger: {}).send(:sanitize, 'test:foo:bar.pdf')
      expect(result).to eq('test_foo_bar.pdf')
    end
  end

  describe '#write' do
    let(:config) do
      double(
        'Config',
        key_path: 'spec/fixtures/files/idme_cert.crt', host: 'sftp.example.com',
        user: 'test_user', port: 22, relative_path: '/remote/path',
        allow_staging_uploads: false
      )
    end

    let(:logger) { instance_double(Logger, info: nil, warn: nil) }
    let(:remote) { described_class.new(config, logger:) }
    let(:mock_sftp) { instance_double(Net::SFTP::Session) }
    let(:mock_uploader) { double('Uploader') }
    let(:filename) { 'test_file.txt' }
    let(:contents) { 'File contents' }

    before do
      allow_any_instance_of(described_class).to receive(:sftp).and_return(mock_sftp)
    end

    context 'when the environment is correctly set to production (Settings.hostname is api.va.gov)' do
      before do
        allow(mock_sftp).to receive(:mkdir!).and_return(true)

        allow(mock_sftp).to receive(:upload!).with(anything, anything) do |_, _, &block|
          if block_given?
            block.call(:open, mock_uploader, 0, nil)
            block.call(:put, mock_uploader, contents.size, contents)
            block.call(:close, mock_uploader, contents.size, nil)
          end
        end

        allow(mock_sftp).to receive(:stat!).with(anything).and_return(double(size: contents.size))

        allow(Settings).to receive(:hostname).and_return('api.va.gov')
      end

      it 'makes remote directories' do
        expect(remote).to receive(:mkdir_safe).with("/remote/path/#{filename}")
        remote.write(contents, filename)
      end

      it 'uploads via sftp' do
        expect(mock_sftp).to receive(:upload!).with(instance_of(StringIO), "/remote/path/#{filename}")
        remote.write(contents, filename)
      end

      it 'returns the number of bytes sent' do
        bytes_sent = remote.write(contents, filename)
        expect(bytes_sent).to eq(contents.size)
      end
    end

    # Settngs.hostname is not 'api.va.gov'
    context 'when the environment is not correctly set to production' do
      it 'does not make remote directories' do
        expect(remote).not_to receive(:mkdir_safe).with("/remote/path/#{filename}")
        remote.write(contents, filename)
      end

      it 'does not upload any data' do
        expect(mock_sftp).not_to receive(:upload!).with(instance_of(StringIO), "/remote/path/#{filename}")
        remote.write(contents, filename)
      end

      it 'returns 0 for bytes sent' do
        bytes_sent = remote.write(contents, filename)
        expect(bytes_sent).to eq(0)
      end
    end
  end
end
