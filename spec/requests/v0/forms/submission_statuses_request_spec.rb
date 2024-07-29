# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateway'

RSpec.describe 'submission_statuses', type: :request do
  let(:user_account_id) { '43134f0c-a772-4afa-857a-e5dedf8ea65a' }

  before do
    sign_in_as(build(:user, :loa3))

    allow_any_instance_of(User).to receive(:user_account).and_return(
      OpenStruct.new(user_account_id:)
    )
  end

  context 'when feature flag disabled' do
    before { Flipper.disable(:my_va_form_submission_statuses) }

    it 'returns a forbidden message' do
      VCR.use_cassette('forms/submission_statuses/200_valid') do
        get '/v0/my_va/submission_statuses'
      end

      expect(response).to have_http_status(:forbidden)

      error = JSON.parse(response.body)['errors'].first
      expect(error['detail']).to eq('Submission statuses are disabled.')
    end
  end

  context 'when feature flag enabled' do
    before do
      Flipper.enable(:my_va_form_submission_statuses)
    end

    context 'when user has submissions' do
      before do
        allow_any_instance_of(Forms::SubmissionStatuses::Gateway).to receive(:submissions).and_return(
          [
            OpenStruct.new(
              id: 1,
              form_type: '21-4142',
              benefits_intake_uuid: '4b846069-e496-4f83-8587-42b570f24483',
              user_account_id:,
              created_at: '2024-03-08'
            ),
            OpenStruct.new(
              id: 2,
              form_type: '21-0966',
              benefits_intake_uuid: 'd0c6cea6-9885-4e2f-8e0c-708d5933833a',
              user_account_id:,
              created_at: '2024-03-13'
            ),
            OpenStruct.new(
              id: 3,
              form_type: '21-10210',
              benefits_intake_uuid: 'd772f671-fbca-4392-ab55-b0e4115dee47',
              user_account_id:,
              created_at: '2024-03-08'
            )
          ]
        )
      end

      it 'returns submission statuses' do
        VCR.use_cassette('forms/submission_statuses/200_valid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(:ok)

        results = JSON.parse(response.body)['data']
        expect(results.size).to eq(3)
      end

      it 'returns all fields' do
        VCR.use_cassette('forms/submission_statuses/200_valid') do
          get '/v0/my_va/submission_statuses'
        end

        expect(response).to have_http_status(:ok)

        results = JSON.parse(response.body)['data']
        keys = %w[id detail form_type message status created_at updated_at]
        expect(results.first['attributes'].keys.sort).to eq(keys.sort)
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
end
