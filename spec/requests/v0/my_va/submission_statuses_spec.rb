# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateways/benefits_intake_gateway'

RSpec.describe 'V0::MyVA::SubmissionStatuses', feature: :form_submission,
                                               team_owner: :vfs_authenticated_experience_backend, type: :request do
  let(:user) { build(:user, :loa1) }
  let(:account_id) { user.user_account_uuid }
  let(:display_all_forms_toggle) { :my_va_display_all_lighthouse_benefits_intake_forms }
  let(:benefits_intake_gateway) { Forms::SubmissionStatuses::Gateways::BenefitsIntakeGateway }

  before do
    sign_in_as(user)
  end

  context 'when user has submissions' do
    before do
      create(:form_submission, :with_form214142, user_account_id: account_id)
      create(:form_submission, :with_form210845, user_account_id: account_id)
      create(:form_submission, :with_form_blocked, user_account_id: account_id)
      allow(Flipper[display_all_forms_toggle]).to receive(:enabled?).and_return(false)
    end

    it 'returns submission statuses' do
      VCR.use_cassette('forms/submission_statuses/200_valid') do
        get '/v0/my_va/submission_statuses'
      end

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)['data']
      expect(results.size).to eq(2)
    end

    it 'returns all fields' do
      VCR.use_cassette('forms/submission_statuses/200_valid') do
        get '/v0/my_va/submission_statuses'
      end

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)['data']
      keys = %w[id detail form_type message status created_at updated_at pdf_support]
      expect(results.first['attributes'].keys.sort).to eq(keys.sort)
    end

    context 'when intake status response has an error' do
      it 'responds with an errors collection' do
        VCR.use_cassette('forms/submission_statuses/401_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)
        keys = %w[status source title detail]

        error = JSON.parse(response.body)['errors'].first
        expect(error.keys.sort).to eq(keys.sort)

        expect(error['source']).to eq('Lighthouse - Benefits Intake API')
      end
    end

    context 'when intake status request is unauthorized' do
      it 'responds with an unauthorized error message' do
        VCR.use_cassette('forms/submission_statuses/401_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)

        error = JSON.parse(response.body)['errors'].first
        expect(error['status']).to eq(401)
        expect(error['title']).to eq('Form Submission Status: Unauthorized')
      end
    end

    context 'when the intake status request payload is too large' do
      it 'responds with a request entity too large message' do
        VCR.use_cassette('forms/submission_statuses/413_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)

        error = JSON.parse(response.body)['errors'].first
        expect(error['status']).to eq(413)
        expect(error['title']).to eq('Form Submission Status: Request Entity Too Large')
      end
    end

    context 'when the intake service is unable to process entity' do
      it 'responds with an unprocessable content message' do
        VCR.use_cassette('forms/submission_statuses/422_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)

        error = JSON.parse(response.body)['errors'].first
        expect(error['status']).to eq(422)
        expect(error['title']).to eq('Form Submission Status: Unprocessable Content')
      end

      context 'when too many requests are sent to the intake service' do
        it 'responds with a rate limit exceeded message' do
          VCR.use_cassette('forms/submission_statuses/429_invalid') do
            get '/v0/my_va/submission_statuses'
          end

          expect(response).to have_http_status(296)

          error = JSON.parse(response.body)['errors'].first
          expect(error['status']).to eq(429)
          expect(error['title']).to eq('Form Submission Status: Too Many Requests')
        end
      end
    end

    context 'when an unexpected intake service server error occurs' do
      it 'returns an internal server error' do
        VCR.use_cassette('forms/submission_statuses/500_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)

        error = JSON.parse(response.body)['errors'].first
        expect(error['status']).to eq(500)
        expect(error['title']).to eq('Form Submission Status: Internal Server Error')
      end
    end

    context 'when the request to the intake service takes too long' do
      it 'returns a getway timeout message' do
        VCR.use_cassette('forms/submission_statuses/504_invalid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(296)

        error = JSON.parse(response.body)['errors'].first
        expect(error['status']).to eq(504)
        expect(error['title']).to eq('Form Submission Status: Gateway Timeout')
      end
    end
  end

  context 'with my_va_display_all_lighthouse_benefits_intake_forms toggle enabled' do
    # Making sure it passed the benefits_intake_gateway#submission_recent? check
    let(:two_days_ago) { 2.days.ago }

    before do
      create(:form_submission, :with_form214142, user_account_id: account_id, created_at: two_days_ago)
      create(:form_submission, :with_form210845, user_account_id: account_id, created_at: two_days_ago)
      create(:form_submission, :with_form_blocked, user_account_id: account_id, created_at: two_days_ago)
    end

    it 'returns all submission statuses including blocked forms' do
      allow(Flipper[display_all_forms_toggle]).to receive(:enabled?).and_return(true)

      VCR.use_cassette('forms/submission_statuses/200_valid_with_blocked_forms') do
        get '/v0/my_va/submission_statuses'
      end

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)['data']
      expect(results.size).to eq(3)
    end
  end

  context 'when user has lighthouse submissions' do
    let!(:saved_claim) { create(:burials_saved_claim, :pending, user_account: user.user_account) }

    before do
      allow_any_instance_of(benefits_intake_gateway).to receive(:form_submissions).and_return([])

      # Mock the Benefits Intake API response to avoid 401 errors
      benefits_intake_uuid = saved_claim.lighthouse_submissions.first.submission_attempts.first.benefits_intake_uuid
      lighthouse_intake_statuses = [
        [{
          'id' => benefits_intake_uuid,
          'attributes' => {
            'status' => 'pending',
            'updated_at' => 1.day.ago,
            'detail' => 'Processing burial claim',
            'guid' => benefits_intake_uuid,
            'message' => 'Form received and processing'
          }
        }],
        nil
      ]
      allow_any_instance_of(benefits_intake_gateway)
        .to receive(:intake_statuses).and_return(lighthouse_intake_statuses)

      allow(Flipper[display_all_forms_toggle]).to receive(:enabled?).and_return(false)
    end

    it 'returns lighthouse submission statuses' do
      get '/v0/my_va/submission_statuses'

      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)['data']
      expect(results.size).to be >= 1
    end
  end

  context 'when user has no submissions' do
    before do
      allow_any_instance_of(benefits_intake_gateway).to receive(:form_submissions).and_return([])
      allow_any_instance_of(benefits_intake_gateway).to receive(:lighthouse_submissions).and_return([])
    end

    it 'returns an empty array' do
      get '/v0/my_va/submission_statuses'

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)['data']
      expect(results).to be_empty
    end
  end
end
