# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::UploadSupportingEvidence', type: :request do
  include SchemaMatchers
  let(:user) { build(:disabilities_compensation_user) }

  let(:pdf_file) do
    fixture_file_upload('doctors-note.pdf', 'application/pdf')
  end

  let(:encrypted_pdf_file) do
    fixture_file_upload('password_is_test.pdf', 'application/pdf')
  end
  let(:long_filename) {
    "supporting_evidenceaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.pdf" } # Simulate a long filename
  let(:long_pdf_file) do
    file = fixture_file_upload('doctors-note.pdf', 'application/pdf')
    # Override the original_filename to simulate a long filename
    allow(file).to receive(:original_filename).and_return(long_filename)
    file
  end

  before do
    sign_in_as(user)
  end

  describe 'Post /v0/upload_supporting_evidence' do
    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
      end

      it 'shortens the filename to the maximum allowed length' do
        post '/v0/upload_supporting_evidence', params: { supporting_evidence_attachment: { file_data: long_pdf_file } }

        expect(response).to have_http_status(:ok)

        attachment = SupportingEvidenceAttachment.last
        file_data = JSON.parse(attachment.file_data)
        expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['filename']).to end_with('.pdf')
      end

      it 'shortens both original and converted filenames when conversion occurs' do
        # Create a long TIFF filename that will trigger conversion
        long_tiff_filename = "supporting_evidence_tiff_" + "a" * 120 + ".tiff"
        long_tiff_file = fixture_file_upload('doctors-note.pdf', 'image/tiff')
        allow(long_tiff_file).to receive(:original_filename).and_return(long_tiff_filename)
        allow(long_tiff_file).to receive(:content_type).and_return('image/tiff')

        post '/v0/upload_supporting_evidence', params: { supporting_evidence_attachment: { file_data: long_tiff_file } }

        expect(response).to have_http_status(:ok)

        attachment = SupportingEvidenceAttachment.last
        file_data = JSON.parse(attachment.file_data)
        
        # Original filename should be shortened
        expect(file_data['filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
        expect(file_data['filename']).to end_with('.tiff')
        expect(file_data['filename']).to include('supporting_evidence_tiff_')
        
        # Converted filename should also be shortened
        # Note: Due to CarrierWave version conditions, conversion may not always happen in test environment
          expect(file_data['converted_filename'].length).to be <= SupportingEvidenceAttachment::MAX_FILENAME_LENGTH
          expect(file_data['converted_filename']).to start_with('converted_')
      end
    end

    context 'with valid encrypted parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: encrypted_pdf_file, password: 'test' } }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
      end

      it 'returns a 422 for a pdf with an incorrect password' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: encrypted_pdf_file, password: 'bad pwd' } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
      end

      it 'returns a 200 for a pdf with a password that was not encrypted' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file, password: 'unnecessary' } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq SupportingEvidenceAttachment.last.guid
      end

      it 'returns a 422 for a malformed pdf' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: fixture_file_upload('malformed-pdf.pdf') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq I18n.t('errors.messages.uploads.pdf.invalid')
      end

      it 'returns a 422 for an unallowed file type' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment:
                       { file_data: fixture_file_upload('invalid_idme_cert.crt') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(
          I18n.t('errors.messages.extension_allowlist_error',
                 extension: '"crt"',
                 allowed_types: SupportingEvidenceAttachmentUploader.new('a').extension_allowlist.join(', '))
        )
      end

      it 'returns a 422 for a file that is too small' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment:
                       { file_data: fixture_file_upload('empty_file.txt') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(I18n.t('errors.messages.min_size_error', min_size: '1 Byte'))
      end
    end

    context 'with invalid parameters' do
      it 'returns a 400 with no parameters' do
        post '/v0/upload_supporting_evidence', params: nil
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns a 400 with no file_data' do
        post '/v0/upload_supporting_evidence', params: { supporting_evidence_attachment: {} }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
