# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DecisionReviewEvidencesontroller', type: :request do
  include SchemaMatchers
  let(:user) { build(:disabilities_compensation_user) }

  let(:pdf_file) do
    fixture_file_upload('files/doctors-note.pdf', 'application/pdf')
  end

  before do
    sign_in_as(user)
  end

  describe 'Post /v0/upload_supporting_evidence' do
    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        post '/v0/decision_review_evidence',
             params: { decision_review_evidence_attachment: { file_data: pdf_file } }
        expect(response).to have_http_status(:ok)
        sea = DecisionReviewEvidenceAttachment.last
        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
        expect(sea.get_file&.read).not_to be_nil
      end
    end

    context 'with valid encrypted parameters' do
      it 'returns a 422  for a file that is too small' do
        post '/v0/decision_review_evidence',
             params: { decision_review_evidence_attachment:
                       { file_data: fixture_file_upload('spec/fixtures/files/empty_file.txt') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(I18n.t('errors.messages.min_size_error', min_size: '1 Byte'))
      end
    end

    context 'with invalid parameters' do
      it 'returns a 500 with no parameters' do
        post '/v0/decision_review_evidence', params: nil
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns a 500 with no file_data' do
        post '/v0/decision_review_evidence', params: { decision_review_evidence_attachment: {} }
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
