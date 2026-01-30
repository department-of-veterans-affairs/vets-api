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

  before do
    sign_in_as(user)
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?).with(:disability_526_supporting_evidence_enhancement,
                                              anything).and_return(false)
  end

  describe 'Post /v0/upload_supporting_evidence' do
    context 'when disability_526_supporting_evidence_enhancement is disabled' do
      it 'returns a 400 for platform upload format' do
        post '/v0/upload_supporting_evidence', params: { file: pdf_file }
        expect(response).to have_http_status(:bad_request)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Missing parameter'
        expect(err['detail']).to include 'supporting_evidence_attachment'
      end

      it 'still accepts legacy nested format' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when disability_526_supporting_evidence_enhancement is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:disability_526_supporting_evidence_enhancement,
                                                  anything).and_return(true)
      end

      it 'accepts platform upload format with flat `file` param' do
        post '/v0/upload_supporting_evidence', params: { file: pdf_file }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
      end

      it 'accepts platform upload format with password' do
        post '/v0/upload_supporting_evidence', params: { file: encrypted_pdf_file, password: 'test' }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
      end

      it 'falls back to legacy nested format when `file` is not present' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
      end

      it 'falls back to nested password when top-level password is an empty string' do
        post '/v0/upload_supporting_evidence',
             params: {
               file: encrypted_pdf_file,
               password: '',
               supporting_evidence_attachment: { password: 'test' }
             }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
      end

      it 'prefers platform `file` param when both payload formats are provided' do
        post '/v0/upload_supporting_evidence',
             params: {
               file: pdf_file,
               supporting_evidence_attachment: { file_data: 'not_a_file_just_a_string' }
             }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
        sea = SupportingEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
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
