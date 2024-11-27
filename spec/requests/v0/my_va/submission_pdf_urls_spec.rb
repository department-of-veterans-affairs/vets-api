# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe 'V0::MyVA::SubmissionPdfUrls', feature: :form_submission,
                                               team_owner: :vfs_authenticated_experience_backend, type: :request do
  let(:user) { build(:user, :loa1) }
  let(:mock_config) { instance_double(SimpleFormsApi::FormRemediation::Configuration::VffConfig) }

  MOCK_URL = 'https://example.com/file1.pdf'
  MOCK_GUID = '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80'
  VALID_FORM_ID = '20-10206'
  

  before do
    sign_in_as(user)
  end

  describe 'POST /v0/my_va/submission_pdf_urls' do
    context 'when pdf download is available' do
      before do
        allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
        allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:fetch_presigned_url).and_return('https://example.com/file1.pdf')
      end

      it 'returns url for the archived pdf' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })

        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        expect(results['url']).to eq(MOCK_URL)
      end
    end

    context 'when pdf download is not available' do
      before do
        allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
        allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:fetch_presigned_url).and_return(nil)
      end

      it 'raises Forbidden error if Form ID is not supported' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: 'BAD_ID', submission_guid: MOCK_GUID })

        expect(response).to have_http_status(:forbidden)
      end

      it 'raises RecordNotFound error if url result is not a string' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })

        expect(response).to have_http_status(:not_found)
      end

      it 'raises Validation error when given bad params' do
        post('/v0/my_va/submission_pdf_urls', params: { f: VALID_FORM_ID, g: MOCK_GUID })
        
        expect(response).to have_http_status(:bad_request)
      end

      it 'raises Validation error when missing a required param' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID })
        
        expect(response).to have_http_status(:bad_request)
      end

      it 'raises Validation error when given extra params' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, guid: MOCK_GUID, extra: 'boo!' })
        
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end