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
