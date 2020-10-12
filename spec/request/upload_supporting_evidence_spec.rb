# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upload supporting evidence', type: :request do
  include SchemaMatchers

  let(:pdf_file) do
    fixture_file_upload('files/doctors-note.pdf')
  end

  let(:encrypted_pdf_file) do
    fixture_file_upload('files/password_is_test.pdf')
  end

  describe 'Post /v0/upload_supporting_evidence' do
    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq SupportingEvidenceAttachment.last.guid
      end
    end

    context 'with valid encrypted parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: encrypted_pdf_file, file_password: 'test' } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq SupportingEvidenceAttachment.last.guid
      end

      it 'returns a 422  for a malformed pdf' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: fixture_file_upload('files/malformed-pdf.pdf') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq 'The uploaded PDF file is invalid and cannot be read'
      end

      it 'returns a 422  for an unallowed file type' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment:
                       { file_data: fixture_file_upload('spec/fixtures/files/invalid_idme_cert.crt') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(
          'You are not allowed to upload "crt" files, allowed types: pdf, png, gif, tiff, tif, jpeg, jpg, bmp, txt'
        )
      end

      it 'returns a 422  for a file that is too small' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment:
                       { file_data: fixture_file_upload('spec/fixtures/files/empty_file.txt') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(
          'File size should be greater than 1 Byte'
        )
      end
    end

    context 'with invalid parameters' do
      it 'returns a 500 with no parameters' do
        post '/v0/upload_supporting_evidence', params: nil
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns a 500 with no file_data' do
        post '/v0/upload_supporting_evidence', params: { supporting_evidence_attachment: {} }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
