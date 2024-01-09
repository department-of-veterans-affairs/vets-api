# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LighthouseDocument do
  describe 'validations' do
    describe '#convert_to_unlock_pdf' do
      let(:tracked_item_id) { 33 }
      let(:document_type) { 'L023' }
      let(:file_name) { 'locked_pdf_password_is_test.pdf' }
      let(:bad_password) { 'bad_pw' }

      context 'when provided password is incorrect' do
        it 'logs a sanitized message to Sentry' do
          error_message = nil
          allow_any_instance_of(LighthouseDocument).to receive(:log_message_to_sentry) do |_, message, _level|
            error_message = message
          end

          tempfile = Tempfile.new(['', "-#{file_name}"])
          file_obj = ActionDispatch::Http::UploadedFile.new(original_filename: file_name, type: 'application/pdf',
                                                            tempfile:)

          document = LighthouseDocument.new(
            file_obj:,
            file_name:,
            tracked_item_id:,
            document_type:,
            password: bad_password
          )

          expect(document.valid?).to be_falsey
          expect(error_message).not_to include(file_name)
          expect(error_message).not_to include(bad_password)
        end
      end
    end
  end
end
