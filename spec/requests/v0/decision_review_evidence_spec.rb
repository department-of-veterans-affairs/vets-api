# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::DecisionReviewEvidence', type: :request do
  include SchemaMatchers
  let(:user) { build(:disabilities_compensation_user) }

  let(:pdf_file) do
    fixture_file_upload('doctors-note.pdf', 'application/pdf')
  end

  before do
    sign_in_as(user)
  end

  describe 'Post /v0/decision_review_evidence' do
    context 'with valid parameters' do
      it 'returns a 200 and an upload guid' do
        VCR.use_cassette('decision_review/200_pdf_validation') do
          post '/v0/decision_review_evidence',
               params: { decision_review_evidence_attachment: { file_data: pdf_file } }
          expect(response).to have_http_status(:ok)
          sea = DecisionReviewEvidenceAttachment.last
          expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq sea.guid
          expect(sea.get_file&.read).not_to be_nil
        end
      end
    end

    context 'with invalid pdf size' do
      it 'returns a 422 and an error message stating the file dimensions are too big' do
        VCR.use_cassette('decision_review/422_page_dimensions_pdf_validation') do
          post '/v0/decision_review_evidence',
               params: { decision_review_evidence_attachment:
                         { file_data: pdf_file } }
          expect(response).to have_http_status(:unprocessable_entity)
          err = JSON.parse(response.body)['errors'][0]
          expect(err['title']).to eq 'Unprocessable Entity'
          expect(err['detail']).to eq(
            'Document exceeds the page size limit of 21 in. x 21 in.'
          )
        end
      end
    end

    context 'with valid encrypted parameters' do
      it 'returns a 422 for a file that not an allowed type' do
        post '/v0/decision_review_evidence',
             params: { decision_review_evidence_attachment:
                       { file_data: fixture_file_upload('saml_responses/loa1.xml',
                                                        'application/xml') } }
        expect(response).to have_http_status(:unprocessable_entity)
        err = JSON.parse(response.body)['errors'][0]
        expect(err['title']).to eq 'Unprocessable Entity'
        expect(err['detail']).to eq(
          'You can’t upload "xml" files. The allowed file types are: pdf'
        )
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
