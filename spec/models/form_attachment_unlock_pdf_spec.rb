# frozen_string_literal: true

require 'rails_helper'

# Minimal stub uploader for testing FormAttachment without coupling to real uploaders
class TestFormAttachmentUploader < CarrierWave::Uploader::Base
  def store_dir
    'test_uploads'
  end
end

# Minimal test subclass to test FormAttachment behavior directly
# without coupling to any specific form type (e.g., Preneeds, HCA, etc.)
class TestFormAttachment < FormAttachment
  self.table_name = 'form_attachments'
  ATTACHMENT_UPLOADER_CLASS = TestFormAttachmentUploader
end

RSpec.describe FormAttachment do
  let(:form_attachment) { TestFormAttachment.new(guid: SecureRandom.uuid) }

  describe '#unlock_pdf' do
    let(:file_name) { 'encrypted_document.pdf' }
    let(:user_password) { 'super_secret_password_123' }

    context 'when provided password is incorrect' do
      let(:tempfile) { Tempfile.new(['', "-#{file_name}"]) }
      let(:file) do
        ActionDispatch::Http::UploadedFile.new(
          original_filename: file_name,
          type: 'application/pdf',
          tempfile: tempfile
        )
      end

      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'raises UnprocessableEntity' do
        expect do
          form_attachment.set_file_data!(file, user_password)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end

      it 'logs a sanitized error message to Rails logger' do
        logged_message = nil
        allow(Rails.logger).to receive(:warn) do |message|
          logged_message = message
        end

        expect do
          form_attachment.set_file_data!(file, user_password)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)

        expect(logged_message).to be_present
        expect(logged_message).not_to include(file_name)
        expect(logged_message).not_to include(user_password)
        expect(logged_message).to include('[FILTERED FILENAME]')
        expect(logged_message).to include('[FILTERED]')
      end

      it 'raises an exception without a cause to prevent leaking sensitive data' do
        expect do
          form_attachment.set_file_data!(file, user_password)
        end.to raise_error(Common::Exceptions::UnprocessableEntity) do |error|
          # The cause should be nil to prevent the original PdftkError
          # (which contains the password) from being logged by error reporters
          expect(error.cause).to be_nil
        end
      end

      it 'does not expose the password anywhere in the exception chain' do
        raised_error = nil
        begin
          form_attachment.set_file_data!(file, user_password)
        rescue Common::Exceptions::UnprocessableEntity => e
          raised_error = e
        end

        # Walk the entire cause chain to ensure no sensitive data leaks
        current = raised_error
        while current
          expect(current.message).not_to include(user_password)
          expect(current.message).not_to include(file_name)
          current = current.cause
        end
      end

      it 'does not expose the filename anywhere in the exception chain' do
        raised_error = nil
        begin
          form_attachment.set_file_data!(file, user_password)
        rescue Common::Exceptions::UnprocessableEntity => e
          raised_error = e
        end

        current = raised_error
        while current
          expect(current.message).not_to include(file_name)
          current = current.cause
        end
      end
    end
  end
end
