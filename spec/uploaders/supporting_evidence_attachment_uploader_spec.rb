# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SupportingEvidenceAttachmentUploader do
  subject { described_class.new(guid) }

  let(:guid) { '1234' }

  it 'allows image, pdf, and text files' do
    expect(subject.extension_allowlist).to match_array %w[pdf png gif tiff tif jpeg jpg bmp txt]
  end

  it 'returns a store directory containing guid' do
    expect(subject.store_dir).to eq "disability_compensation_supporting_form/#{guid}"
  end

  it 'throws an error if no guid is given' do
    blank_uploader = described_class.new(nil)
    expect { blank_uploader.store_dir }.to raise_error(RuntimeError, 'missing guid')
  end

  describe 'filename shortening' do
    describe 'CarrierWave integration tests' do
      let(:long_filename) { "#{'very_long_document_name' * 8}.pdf" } # ~200 characters
      let(:expected_shortened) { long_filename[0, 96] + '.pdf' } # 100 chars total

      it 'stores main file with shortened filename' do
        # Create a real file upload scenario
        file_path = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf')
        uploaded_file = Rack::Test::UploadedFile.new(file_path, 'application/pdf', true)
        
        # Mock the original filename to be long
        allow(uploaded_file).to receive(:original_filename).and_return(long_filename)
        
        uploader = described_class.new('test-guid')
        
        # Test the filename method behavior (what CarrierWave calls to get the stored name)
        allow(uploader).to receive(:original_filename).and_return(long_filename)
        shortened_result = uploader.filename
        
        expect(shortened_result.length).to eq(100)
        expect(shortened_result).to end_with('.pdf')
        expect(shortened_result).to start_with('very_long_document_name')
      end

      it 'creates converted version with shortened filename when TIFF conversion needed' do
        uploader = described_class.new('test-guid')
        long_tiff_name = "#{'tiff_document' * 15}.tiff" # Long TIFF filename
        
        # Mock the uploader to simulate TIFF file
        allow(uploader).to receive(:original_filename).and_return(long_tiff_name)
        allow(uploader).to receive(:tiff?).and_return(true)
        allow(uploader).to receive(:tiff_or_incorrect_extension?).and_return(true)
        
        converted_version = uploader.converted
        converted_filename = converted_version.full_filename(long_tiff_name)
        
        expect(converted_filename).to start_with('converted_')
        expect(converted_filename.length).to be <= (described_class::MAX_FILENAME_LENGTH + 'converted_'.length)
        expect(converted_filename).to include('tiff_document')
      end
    end

    describe '#filename' do
      context 'when original_filename exceeds MAX_FILENAME_LENGTH' do
        it 'shortens the filename while preserving extension' do
          long_filename = "#{'a' * 120}.pdf" # 124 characters
          allow(subject).to receive(:original_filename).and_return(long_filename)

          result = subject.filename

          expect(result.length).to eq(100) # Exactly at MAX_FILENAME_LENGTH
          expect(result).to end_with('.pdf')
          expect(result).to start_with('a' * 96) # 96 + 4 for '.pdf' = 100
        end

        it 'handles different extensions correctly' do
          long_filename = "#{'test' * 30}.jpeg" # 125 characters
          allow(subject).to receive(:original_filename).and_return(long_filename)

          result = subject.filename

          expect(result.length).to eq(100)
          expect(result).to end_with('.jpeg')
        end

        it 'handles files with no extension' do
          long_filename = 'a' * 120 # 120 characters, no extension
          allow(subject).to receive(:original_filename).and_return(long_filename)

          result = subject.filename

          expect(result.length).to eq(100)
          expect(result).to eq('a' * 100)
        end
      end

      context 'when original_filename is within MAX_FILENAME_LENGTH' do
        it 'does not modify short filenames' do
          short_filename = 'document.pdf'
          allow(subject).to receive(:original_filename).and_return(short_filename)

          result = subject.filename

          expect(result).to eq('document.pdf')
        end

        it 'does not modify filenames exactly at the limit' do
          exact_filename = "#{'a' * 96}.pdf" # Exactly 100 characters
          allow(subject).to receive(:original_filename).and_return(exact_filename)

          result = subject.filename

          expect(result).to eq(exact_filename)
          expect(result.length).to eq(100)
        end
      end

      context 'when original_filename is nil' do
        it 'returns nil' do
          allow(subject).to receive(:original_filename).and_return(nil)

          result = subject.filename

          expect(result).to be_nil
        end
      end
    end

    describe '#converted version with shortened filenames' do
      it 'shortens filenames in the converted version' do
        uploader = described_class.new('test-guid')
        long_original = 'a' * 150 + '.pdf'
        
        # Test that the converted version uses shortened filename
        converted_version = uploader.converted
        allow(converted_version).to receive(:shorten_filename).and_call_original
        
        result = converted_version.full_filename(long_original)
        
        # Should have called shorten_filename and used result in converted name
        expect(converted_version).to have_received(:shorten_filename).with(long_original)
        expect(result).to start_with('converted_')
        expect(result.length).to be <= (described_class::MAX_FILENAME_LENGTH + 10) # +10 for "converted_"
      end
    end

    describe '#shorten_filename (private method)' do
      it 'shortens long filenames while preserving extensions' do
        long_filename = "#{'document' * 15}.pdf"
        shortened = subject.send(:shorten_filename, long_filename)

        expect(shortened.length).to eq(100)
        expect(shortened).to end_with('.pdf')
      end

      it 'returns unchanged short filenames' do
        short_filename = 'test.pdf'
        shortened = subject.send(:shorten_filename, short_filename)

        expect(shortened).to eq('test.pdf')
      end
    end
  end

  describe 'logging methods' do
    let(:mock_file) do
      double('uploaded_file', size: 1024, headers: {
               'Content-Type' => 'application/pdf',
               'User-Agent' => 'Mozilla/5.0',
               'filename' => 'PII.pdf'
             })
    end

    describe '#log_transaction_start' do
      it 'logs process_id, filesize, and upload_start without file_headers' do
        freeze_time = Time.parse('2025-08-26 12:00:00 UTC')

        allow(Time).to receive(:current).and_return(freeze_time)
        allow(Rails.logger).to receive(:info)

        subject.log_transaction_start(mock_file)

        expected_log = {
          process_id: Process.pid,
          filesize: 1024,
          upload_start: freeze_time
        }

        expect(Rails.logger).to have_received(:info).with(expected_log)
      end

      it 'does not log file headers which could contain PII' do
        allow(Rails.logger).to receive(:info) do |log_data|
          expect(log_data).not_to have_key(:file_headers)
          expect(log_data.values.join).not_to include('Mozilla')
          expect(log_data.values.join).not_to include('User-Agent')
          expect(log_data.values.join).not_to include('PII.pdf')
        end

        subject.log_transaction_start(mock_file)

        expect(Rails.logger).to have_received(:info)
      end
    end

    describe '#log_transaction_complete' do
      it 'logs process_id, filesize, and upload_complete without file_headers' do
        freeze_time = Time.parse('2025-08-26 12:00:00 UTC')

        allow(Time).to receive(:current).and_return(freeze_time)
        allow(Rails.logger).to receive(:info)

        subject.log_transaction_complete(mock_file)

        expected_log = {
          process_id: Process.pid,
          filesize: 1024,
          upload_complete: freeze_time
        }

        expect(Rails.logger).to have_received(:info).with(expected_log)
      end

      it 'does not log file headers which could contain PII' do
        allow(Rails.logger).to receive(:info) do |log_data|
          expect(log_data).not_to have_key(:file_headers)
          expect(log_data.values.join).not_to include('Mozilla')
          expect(log_data.values.join).not_to include('User-Agent')
        end

        subject.log_transaction_complete(mock_file)

        expect(Rails.logger).to have_received(:info)
      end
    end
  end
end
