# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api/form_remediation/configuration/vff_config'
require 'feature_flipper'

MOCK_URL = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'
MOCK_404_URL = 'https://example.com/file1.pdf'
MOCK_GUID = '3b03b5a0-3ad9-4207-b61e-3a13ed1c8b80'
VALID_FORM_ID = '20-10206'

RSpec.describe 'V0::MyVA::SubmissionPdfUrls', feature: :form_submission,
                                              team_owner: :vfs_authenticated_experience_backend,
                                              type: :request do
  let(:user) { create(:user, :loa1) }
  let(:user_account) { user.user_account }
  let(:mock_config) { instance_double(SimpleFormsApi::FormRemediation::Configuration::VffConfig) }

  before do
    sign_in_as(user)
    Flipper.enable('my_va_form_submission_pdf_link') # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  describe 'POST /v0/my_va/submission_pdf_urls' do
    context 'when user owns the submission and pdf download is available' do
      let(:form_submission) { create(:form_submission, user_account:) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before do
        form_submission_attempt
        allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
        allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:fetch_presigned_url).and_return(MOCK_URL)
      end

      it 'returns url for the archived pdf' do
        VCR.use_cassette('my_va/submission_pdf_urls') do
          post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        end
        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        expect(results['url']).to eq(MOCK_URL)
      end
    end

    context 'when user does not own the submission' do
      let(:other_user_account) { create(:user_account) }
      let(:form_submission) { create(:form_submission, user_account: other_user_account) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before do
        form_submission_attempt
      end

      it 'raises Forbidden error' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when submission does not exist' do
      it 'raises Forbidden error' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when both submission.user_account_id and current_user.user_account are nil' do
      let(:form_submission) { create(:form_submission, user_account: nil) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before do
        form_submission_attempt
        allow_any_instance_of(User).to receive(:user_account).and_return(nil)
      end

      it 'raises Forbidden error (prevents nil == nil from passing)' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when user owns submission but pdf does not exist in S3' do
      let(:form_submission) { create(:form_submission, user_account:) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before do
        form_submission_attempt
        allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
        allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:fetch_presigned_url).and_return(MOCK_404_URL)
      end

      it 'raises RecordNotFound error' do
        VCR.use_cassette('my_va/submission_pdf_urls_404') do
          post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        end
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when user owns submission but pdf url is nil' do
      let(:form_submission) { create(:form_submission, user_account:) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before do
        form_submission_attempt
        allow(SimpleFormsApi::FormRemediation::Configuration::VffConfig).to receive(:new).and_return(mock_config)
        allow(SimpleFormsApi::FormRemediation::S3Client).to receive(:fetch_presigned_url).and_return(nil)
      end

      it 'raises RecordNotFound error if url result is not a string' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, submission_guid: MOCK_GUID })
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when Form ID is not supported' do
      let(:form_submission) { create(:form_submission, user_account:) }
      let(:form_submission_attempt) do
        create(:form_submission_attempt, form_submission:, benefits_intake_uuid: MOCK_GUID)
      end

      before { form_submission_attempt }

      it 'raises Forbidden error' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: 'BAD_ID', submission_guid: MOCK_GUID })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when request params are invalid' do
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

    context 'when feature toggle is disabled' do
      before do
        Flipper.disable('my_va_form_submission_pdf_link') # rubocop:disable Project/ForbidFlipperToggleInSpecs
      end

      it 'raises Forbidden error' do
        post('/v0/my_va/submission_pdf_urls', params: { form_id: VALID_FORM_ID, guid: MOCK_GUID })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
