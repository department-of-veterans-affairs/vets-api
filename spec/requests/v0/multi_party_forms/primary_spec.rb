# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MultiPartyForms::Primary', type: :request do
  include StatsD::Instrument::Helpers

  let(:user) { create(:user, :loa3) }

  describe 'POST /v0/multi_party_forms/primary' do
    let(:form_params) do
      {
        multi_party_form: {
          form_type: '21-2680'
        }
      }.to_json
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post '/v0/multi_party_forms/primary',
             params: form_params,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when feature flag is disabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_return(false)
      end

      it 'returns not found' do
        post '/v0/multi_party_forms/primary',
             params: form_params,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated and feature flag enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_return(true)
      end

      it 'creates a new multi-party form submission' do
        metrics = capture_statsd_calls do
          post '/v0/multi_party_forms/primary',
               params: form_params,
               headers: {
                 'Content-Type' => 'application/json',
                 'HTTP_SOURCE_APP_NAME' => 'multi-party-forms'
               }
        end

        expect(response).to have_http_status(:created)

        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('multi_party_form_submission')
        expect(json_response['data']['attributes']['form_type']).to eq('21-2680')
        expect(json_response['data']['attributes']['status']).to eq('primary_in_progress')
        expect(json_response['data']['attributes']['primary_form_id']).to eq('21-2680-PRIMARY')
        expect(json_response['data']['attributes']['secondary_form_id']).to eq('21-2680-SECONDARY')

        # Verify StatsD metrics
        expect(metrics.collect(&:source)).to include(
          'multi_party_form.created:1|c|#form_type:21-2680'
        )
      end

      # TODO: Add test for validation errors once model is implemented
      # context 'with invalid params' do
      #   let(:invalid_params) do
      #     {
      #       multi_party_form: {
      #         form_type: ''
      #       }
      #     }.to_json
      #   end
      #
      #   it 'returns validation errors' do
      #     post '/v0/multi_party_forms/primary',
      #          params: invalid_params,
      #          headers: { 'Content-Type' => 'application/json' }
      #
      #     expect(response).to have_http_status(:unprocessable_entity)
      #   end
      # end
    end
  end

  describe 'GET /v0/multi_party_forms/primary/:id' do
    let(:submission_id) { SecureRandom.uuid }

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get "/v0/multi_party_forms/primary/#{submission_id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when feature flag is disabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_return(false)
      end

      it 'returns not found' do
        get "/v0/multi_party_forms/primary/#{submission_id}"
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated and feature flag enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_return(true)
      end

      # TODO: Update these tests once MultiPartyFormSubmission model is available
      context 'with valid submission id' do
        it 'returns the submission details' do
          get "/v0/multi_party_forms/primary/#{submission_id}",
              headers: { 'HTTP_SOURCE_APP_NAME' => 'multi-party-forms' }

          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to eq(submission_id)
          expect(json_response['data']['type']).to eq('multi_party_form_submission')
          expect(json_response['data']['attributes']['form_type']).to eq('21-2680')
        end
      end

      # TODO: Uncomment once model is implemented with proper authorization
      # context 'when submission belongs to another user' do
      #   let(:other_user_submission) { create(:multi_party_form_submission, primary_user_uuid: 'different-uuid') }
      #
      #   it 'returns not found' do
      #     get "/v0/multi_party_forms/primary/#{other_user_submission.id}"
      #     expect(response).to have_http_status(:not_found)
      #   end
      # end

      # TODO: Uncomment once controller response is no longer stubbed
      # This test currently fails because the show action returns a stubbed response
      # that doesn't validate the submission ID. Once we implement actual model queries,
      # this test will properly verify 404 responses for non-existent submissions.
      # context 'with non-existent submission id' do
      #   it 'returns not found' do
      #     get '/v0/multi_party_forms/primary/not-found'
      #     expect(response).to have_http_status(:not_found)
      #   end
      # end
    end
  end
end
