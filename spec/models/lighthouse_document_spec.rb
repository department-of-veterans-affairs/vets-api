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
        shared_examples 'logs a sanitized error message' do
          it 'logs a sanitized message without sensitive data' do
            error_message = nil
            allow_any_instance_of(Vets::SharedLogging).to receive(:log_exception_to_rails) do |_, error, _level|
              error_message = error.message
            end

            tempfile = Tempfile.new(['', "-#{file_name}"])
            file_obj = ActionDispatch::Http::UploadedFile.new(
              original_filename: file_name,
              type: 'application/pdf',
              tempfile:
            )

            document = LighthouseDocument.new(
              file_obj:,
              file_name:,
              tracked_item_id:,
              document_type:,
              password: bad_password
            )

            expect(document).not_to be_valid
            expect(error_message).not_to include(file_name)
            expect(error_message).not_to include(bad_password)
          end
        end

        context 'pdftk' do
          before do
            allow(Flipper).to receive(:enabled?)
              .with(:lighthouse_document_convert_to_unlocked_pdf_use_hexapdf)
              .and_return(false)
          end

          it_behaves_like 'logs a sanitized error message'
        end

        context 'hexapdf' do
          before do
            allow(Flipper).to receive(:enabled?)
              .with(:lighthouse_document_convert_to_unlocked_pdf_use_hexapdf)
              .and_return(true)
          end

          it_behaves_like 'logs a sanitized error message'
        end
      end
    end
  end

  describe '#to_serializable_hash' do
    it 'does not return file_obj' do
      f = Tempfile.new(['file with spaces', '.txt'])
      f.write('test')
      f.rewind
      rack_file = Rack::Test::UploadedFile.new(f.path, 'text/plain')

      upload_file = ActionDispatch::Http::UploadedFile.new(
        tempfile: rack_file.tempfile,
        filename: rack_file.original_filename,
        type: rack_file.content_type
      )

      document = EVSSClaimDocument.new(
        evss_claim_id: 1,
        tracked_item_id: 1,
        file_obj: upload_file,
        file_name: File.basename(upload_file.path)
      )

      expect(document.to_serializable_hash.keys).not_to include(:file_obj)
      expect(document.to_serializable_hash.keys).not_to include('file_obj')
    end
  end
end
