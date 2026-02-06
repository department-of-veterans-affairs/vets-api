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

  describe '#filename' do
    context 'when no file has been stored' do
      it 'returns nil' do
        expect(subject.filename).to be_nil
      end
    end

    context 'when filename is within MAX_FILENAME_LENGTH' do
      let(:short_filename) { 'short_file.pdf' }

      before do
        # CarrierWave's filename method uses @filename internally after sanitization
        subject.instance_variable_set(:@filename, short_filename)
      end

      it 'returns the filename unchanged' do
        expect(subject.filename).to eq(short_filename)
      end
    end

    context 'when filename exceeds MAX_FILENAME_LENGTH' do
      let(:long_filename) { "#{'a' * 150}.pdf" }

      before do
        subject.instance_variable_set(:@filename, long_filename)
      end

      it 'returns a shortened filename' do
        result = subject.filename
        expect(result.length).to be <= described_class::MAX_FILENAME_LENGTH
      end

      it 'preserves the file extension' do
        result = subject.filename
        expect(result).to end_with('.pdf')
      end
    end

    context 'when filename has a long extension' do
      let(:long_ext_filename) { "#{'a' * 150}.jpeg" }

      before do
        subject.instance_variable_set(:@filename, long_ext_filename)
      end

      it 'accounts for extension length in the shortened result' do
        result = subject.filename
        expect(result.length).to be <= described_class::MAX_FILENAME_LENGTH
        expect(result).to end_with('.jpeg')
      end
    end
  end

  describe '#shorten_filename' do
    context 'when filename is within MAX_FILENAME_LENGTH' do
      it 'returns the filename unchanged' do
        expect(subject.send(:shorten_filename, 'short.pdf')).to eq('short.pdf')
      end
    end

    context 'when filename is exactly MAX_FILENAME_LENGTH' do
      let(:exact_filename) { "#{'a' * 96}.pdf" } # 96 + 4 (.pdf) = 100

      it 'returns the filename unchanged' do
        expect(subject.send(:shorten_filename, exact_filename)).to eq(exact_filename)
      end
    end

    context 'when filename exceeds MAX_FILENAME_LENGTH' do
      let(:long_filename) { "#{'a' * 150}.pdf" }

      it 'returns a shortened filename within limit' do
        result = subject.send(:shorten_filename, long_filename)
        expect(result.length).to be <= described_class::MAX_FILENAME_LENGTH
      end

      it 'preserves the file extension' do
        result = subject.send(:shorten_filename, long_filename)
        expect(result).to end_with('.pdf')
      end
    end

    context 'when filename has no extension' do
      let(:long_filename_no_ext) { 'a' * 150 }

      it 'shortens to MAX_FILENAME_LENGTH' do
        result = subject.send(:shorten_filename, long_filename_no_ext)
        expect(result.length).to eq(described_class::MAX_FILENAME_LENGTH)
      end
    end

    context 'when filename has multiple dots' do
      let(:multi_dot_filename) { "#{'a' * 150}.document.v2.pdf" }

      it 'preserves only the last extension' do
        result = subject.send(:shorten_filename, multi_dot_filename)
        expect(result).to end_with('.pdf')
        expect(result.length).to be <= described_class::MAX_FILENAME_LENGTH
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
