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
        it 'logs a sanitized message to Sentry and Rails' do
          error_message = nil
          allow_any_instance_of(FormAttachment).to receive(:log_message_to_sentry) do |_, message, _level|
            error_message = message
          end
          allow(Rails.logger).to receive(:warn)

          tempfile = Tempfile.new(['', "-#{file_name}"])
          file = ActionDispatch::Http::UploadedFile.new(original_filename: file_name, type: 'application/pdf',
                                                        tempfile:)

          expect do
            preneed_attachment.set_file_data!(file, bad_password)
          end.to raise_error(Common::Exceptions::UnprocessableEntity)
          expect(error_message).not_to include(file_name)
          expect(error_message).not_to include(bad_password)
          expect(Rails.logger).to have_received(:warn)
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
