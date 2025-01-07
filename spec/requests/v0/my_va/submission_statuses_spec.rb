# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateway'

RSpec.describe 'V0::MyVA::SubmissionStatuses', feature: :form_submission,
                                               team_owner: :vfs_authenticated_experience_backend, type: :request do
  let(:user) { build(:user, :loa1) }

  before do
    sign_in_as(user)
  end

  context 'when user has submissions' do
    before do
      create(:form_submission, :with_form214142, user_account_id: user.user_account_uuid)
      create(:form_submission, :with_form210845, user_account_id: user.user_account_uuid)
      create(:form_submission, :with_form_blocked, user_account_id: user.user_account_uuid)
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

  context 'when user has no submissions' do
    before do
      allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:submissions).and_return([])
    end

    it 'returns an empty array' do
      get '/v0/my_va/submission_statuses'

      expect(response).to have_http_status(:ok)

      results = JSON.parse(response.body)['data']
      expect(results).to be_empty
    end
  end
end
