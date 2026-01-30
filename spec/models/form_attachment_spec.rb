# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormAttachment do
  let(:preneed_attachment) { build(:preneed_attachment) }

  describe '#set_file_data!' do
    it 'stores the file and set the file_data' do
      expect(preneed_attachment.parsed_file_data['filename']).to eq('extras.pdf')
    end

    describe '#unlock_pdf' do
      let(:file_name) { 'locked_pdf_password_is_test.Pdf' }
      let(:bad_password) { 'bad_pw' }

      context 'when provided password is incorrect' do
        let(:tempfile) { Tempfile.new(['', "-#{file_name}"]) }
        let(:file) do
          ActionDispatch::Http::UploadedFile.new(original_filename: file_name, type: 'application/pdf', tempfile:)
        end

        before do
          allow(Rails.logger).to receive(:warn)
        end

        it 'logs a sanitized message to Rails logger' do
          error_message = nil
          allow(Rails.logger).to receive(:warn) do |message|
            error_message = message
          end

          expect do
            preneed_attachment.set_file_data!(file, bad_password)
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
          expect(error_message).not_to include(file_name)
          expect(error_message).not_to include(bad_password)
        end

        it 'raises an exception without a cause to prevent leaking sensitive data' do
          raised_error = nil
          begin
            preneed_attachment.set_file_data!(file, bad_password)
          rescue Common::Exceptions::UnprocessableEntity => e
            raised_error = e
          end

          expect(raised_error).to be_present
          expect(raised_error.cause).to be_nil
        end

        it 'does not expose the original PdftkError with password in the exception chain' do
          raised_error = nil
          begin
            preneed_attachment.set_file_data!(file, bad_password)
          rescue Common::Exceptions::UnprocessableEntity => e
            raised_error = e
          end

          # Walk the entire cause chain to ensure no sensitive data leaks
          current = raised_error
          while current
            expect(current.message).not_to include(bad_password)
            current = current.cause
          end
        end
      end
    end
  end

  describe '#get_file' do
    it 'gets the file from storage' do
      preneed_attachment.save!
      preneed_attachment2 = Preneeds::PreneedAttachment.find(preneed_attachment.id)
      file = preneed_attachment2.get_file

      expect(file.exists?).to be(true)
    end
  end
end
