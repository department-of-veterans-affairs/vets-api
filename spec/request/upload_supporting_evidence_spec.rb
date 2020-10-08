# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Upload supporting evidence', type: :request do
  include SchemaMatchers

  describe 'Post /v0/upload_supporting_evidence' do
    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: fixture_file_upload('files/sm_file1.jpg') } }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq SupportingEvidenceAttachment.last.guid
      end

      it 'returns a 422  for a bad file' do
        post '/v0/upload_supporting_evidence',
             params: { supporting_evidence_attachment: { file_data: fixture_file_upload('files/malformed-pdf.pdf') } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['errors'][0]['title']).to eq 'Unprocessable Entity'
      end
    end

    context 'with invalid parameters' do
      it 'returns a 500 with no parameters' do
        post '/v0/upload_supporting_evidence', params: nil
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns a 500 with no file_data' do
        post '/v0/upload_supporting_evidence', params: JSON.parse('{"supporting_evidence_attachment": {}}')
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
