# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::VirusScan do
  let(:test_file_content) { 'test file content' }
  let(:clamav_client) { instance_double(ClamAV::PatchClient) }

  before do
    # Reset directories before each test
    FileUtils.rm_rf('tmp/pdfs')
    FileUtils.mkdir_p('tmp/pdfs')
    FileUtils.mkdir_p('clamav_tmp')

    # Stub ClamAV client
    allow(ClamAV::PatchClient).to receive(:new).and_return(clamav_client)
    allow(clamav_client).to receive(:safe?).and_return(true)

    # Stub Settings without receive_message_chain
    allow(Settings.clamav).to receive(:mock).and_return(false)
  end

  after do
    # Cleanup test files
    FileUtils.rm_rf('tmp/pdfs')
    Dir.glob('clamav_tmp/scan_*').each { |f| File.delete(f) }
  end

  describe '.scan' do
    context 'when file does not exist' do
      it 'raises an error' do
        expect { described_class.scan('nonexistent_file.pdf') }
          .to raise_error('Failed to create temp file')
      end
    end

    context 'when mock is enabled' do
      before do
        allow(Settings.clamav).to receive(:mock).and_return(true)
      end

      it 'returns true without scanning' do
        file_path = 'tmp/pdfs/test.pdf'
        File.write(file_path, test_file_content)

        expect(ClamAV::PatchClient).not_to receive(:new)
        expect(described_class.scan(file_path)).to be true
      end
    end

    context 'when file is already in clamav_tmp/' do
      let(:file_path) { 'clamav_tmp/existing_file.pdf' }

      before do
        File.write(file_path, test_file_content)
      end

      it 'scans the file directly' do
        expect(Rails.logger).to receive(:info).with('Scanning file already in clamav_tmp')
        expect(clamav_client).to receive(:safe?).with(file_path).and_return(true)

        result = described_class.scan(file_path)
        expect(result).to be true
      end

      it 'does not create a temporary copy' do
        expect(FileUtils).not_to receive(:cp)

        described_class.scan(file_path)
      end

      it 'sets correct file permissions' do
        expect(File).to receive(:chmod).with(0o640, file_path)

        described_class.scan(file_path)
      end

      context 'when scan finds a virus' do
        before do
          allow(clamav_client).to receive(:safe?).and_return(false)
        end

        it 'returns false' do
          result = described_class.scan(file_path)
          expect(result).to be false
        end
      end
    end

    context 'when file is in another location' do
      let(:file_path) { 'tmp/pdfs/document.pdf' }

      before do
        File.write(file_path, test_file_content)
      end

      context 'when flipper flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:clamav_scan_file_from_other_location).and_return(true)
        end

        it 'creates a temporary copy in clamav_tmp/' do
          expect(FileUtils).to receive(:cp).with(file_path, %r{clamav_tmp/scan_.*_document\.pdf})
                                           .and_call_original

          described_class.scan(file_path)
        end

        it 'scans the temporary copy' do
          expect(clamav_client).to receive(:safe?).with(%r{clamav_tmp/scan_.*_document\.pdf})
                                                  .and_return(true)

          result = described_class.scan(file_path)
          expect(result).to be true
        end

        it 'cleans up the temporary copy after scanning' do
          described_class.scan(file_path)

          # Verify no temp files left
          temp_files = Dir.glob('clamav_tmp/scan_*')
          expect(temp_files).to be_empty
        end

        it 'preserves the original file' do
          described_class.scan(file_path)

          expect(File.exist?(file_path)).to be true
          expect(File.read(file_path)).to eq(test_file_content)
        end

        it 'logs the scan process' do
          expect(Rails.logger).to receive(:info).with("Creating clamav tmp file for: #{file_path}")
          expect(Rails.logger).to receive(:info).with("Created clamav tmp file: #{file_path}")
          expect(Rails.logger).to receive(:info).with(/Deleted temp scan file: clamav_tmp/)

          described_class.scan(file_path)
        end

        it 'sets correct permissions on both files' do
          expect(File).to receive(:chmod).with(0o640, file_path).and_call_original
          expect(File).to receive(:chmod).with(0o640, %r{clamav_tmp/scan_}).and_call_original

          described_class.scan(file_path)
        end

        context 'when scan finds a virus' do
          before do
            allow(clamav_client).to receive(:safe?).and_return(false)
          end

          it 'returns false' do
            result = described_class.scan(file_path)
            expect(result).to be false
          end

          it 'still cleans up the temporary file' do
            described_class.scan(file_path)

            temp_files = Dir.glob('clamav_tmp/scan_*')
            expect(temp_files).to be_empty
          end
        end

        context 'when copy fails' do
          before do
            allow(FileUtils).to receive(:cp).and_raise(Errno::EACCES, 'Permission denied')
          end

          it 'raises the error' do
            expect { described_class.scan(file_path) }
              .to raise_error(Errno::EACCES)
          end

          it 'logs the error' do
            expect(Rails.logger).to receive(:error)
              .with(/VirusScan failed for #{file_path}/)

            expect { described_class.scan(file_path) }.to raise_error(Errno::EACCES)
          end

          it 'attempts cleanup even on error' do
            expect(described_class).to receive(:delete_file_if_exists).at_least(:once)

            expect { described_class.scan(file_path) }.to raise_error(Errno::EACCES)
          end
        end

        context 'when scan raises an error' do
          before do
            allow(clamav_client).to receive(:safe?).and_raise(StandardError, 'Connection refused')
          end

          it 'raises the error' do
            expect { described_class.scan(file_path) }
              .to raise_error(StandardError, 'Connection refused')
          end

          it 'cleans up the temporary file' do
            expect { described_class.scan(file_path) }.to raise_error(StandardError)

            temp_files = Dir.glob('clamav_tmp/scan_*')
            expect(temp_files).to be_empty
          end
        end
      end

      context 'when flipper flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:clamav_scan_file_from_other_location).and_return(false)
        end

        it 'returns false' do
          result = described_class.scan(file_path)
          expect(result).to be false
        end

        it 'does not scan the file' do
          expect(clamav_client).not_to receive(:safe?)

          described_class.scan(file_path)
        end

        it 'logs a warning' do
          expect(Rails.logger).to receive(:warn)
            .with("Clamav scan from other location disabled for: #{file_path}")

          described_class.scan(file_path)
        end

        it 'does not create temporary files' do
          described_class.scan(file_path)

          temp_files = Dir.glob('clamav_tmp/scan_*')
          expect(temp_files).to be_empty
        end
      end
    end

    context 'with concurrent scans of the same file' do
      let(:file_path) { 'tmp/pdfs/concurrent.pdf' }

      before do
        File.write(file_path, test_file_content)
        allow(Flipper).to receive(:enabled?).with(:clamav_scan_file_from_other_location).and_return(true)
      end

      # rubocop:disable ThreadSafety/NewThread
      it 'handles concurrent scans without collision' do
        threads = 5.times.map do
          Thread.new { described_class.scan(file_path) }
        end

        results = threads.map(&:value)

        expect(results).to all(be true)

        # Verify all temp files were cleaned up
        temp_files = Dir.glob('clamav_tmp/scan_*')
        expect(temp_files).to be_empty
      end
      # rubocop:enable ThreadSafety/NewThread
    end
  end

  describe '.scan_file_from_other_location' do
    let(:file_path) { 'tmp/pdfs/test.pdf' }

    before do
      File.write(file_path, test_file_content)
    end

    it 'creates clamav_tmp directory if it does not exist' do
      Dir.glob('clamav_tmp/scan_*').each { |f| File.delete(f) }

      described_class.scan_file_from_other_location(file_path)

      expect(Dir.exist?('clamav_tmp')).to be true
    end

    it 'generates unique filenames' do
      # Prevent deletion so we can inspect files
      allow(described_class).to receive(:delete_file_if_exists)

      # Perform multiple scans
      5.times { described_class.scan_file_from_other_location(file_path) }

      # Should have 5 unique temp files
      temp_files = Dir.glob('clamav_tmp/scan_*_test.pdf')
      expect(temp_files.length).to eq(5)

      # All filenames should be unique
      expect(temp_files.uniq.length).to eq(5)

      # All should match the pattern
      expect(temp_files).to all(match(%r{clamav_tmp/scan_\d+_[a-f0-9]{16}_test\.pdf}))

      # Cleanup
      FileUtils.rm_rf('clamav_tmp/scan_*')
    end
  end

  describe '.delete_file_if_exists' do
    it 'deletes the file if it exists' do
      file_path = 'clamav_tmp/temp_file.pdf'
      File.write(file_path, test_file_content)

      expect(Rails.logger).to receive(:info).with("Deleted temp scan file: #{file_path}")

      described_class.delete_file_if_exists(file_path)

      expect(File.exist?(file_path)).to be false
    end

    it 'does nothing if file does not exist' do
      expect(Rails.logger).not_to receive(:info)

      described_class.delete_file_if_exists('nonexistent.pdf')
    end

    it 'does nothing if file_path is nil' do
      expect { described_class.delete_file_if_exists(nil) }.not_to raise_error
    end

    it 'handles deletion errors gracefully' do
      file_path = 'clamav_tmp/temp_file.pdf'
      File.write(file_path, test_file_content)

      allow(File).to receive(:delete).and_raise(Errno::EACCES, 'Permission denied')

      expect(Rails.logger).to receive(:warn)
        .with(/Failed to delete temp file #{file_path}/)

      expect { described_class.delete_file_if_exists(file_path) }.not_to raise_error
    end
  end

  describe '.mock_enabled?' do
    it 'returns true when Settings.clamav.mock is true' do
      allow(Settings.clamav).to receive(:mock).and_return(true)

      expect(described_class.mock_enabled?).to be true
    end

    it 'returns false when Settings.clamav.mock is false' do
      allow(Settings.clamav).to receive(:mock).and_return(false)

      expect(described_class.mock_enabled?).to be false
    end
  end
end
