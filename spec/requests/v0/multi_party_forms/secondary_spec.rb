# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MultiPartyForms::Secondary', type: :request do
  let(:user) { create(:user, :loa3) }
  let(:submission) do
    create(
      :multi_party_form_submission,
      :with_secondary,
      status: 'awaiting_secondary_start'
    )
  end

  describe 'POST /v0/multi_party_forms/secondary/:id/start' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when feature flag is disabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_2680_multi_party_forms_enabled, anything).and_return(false)
      end

      it 'returns not found' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated and feature flag enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_2680_multi_party_forms_enabled, anything).and_return(true)
      end

      it 'starts the secondary flow and returns submission JSON' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('multi_party_form_submission')
        expect(json_response['data']['attributes']['status']).to eq('secondary_in_progress')
      end

      it 'returns 403 forbidden with invalid token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: 'invalid-token' }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with expired token' do
        token = submission.generate_secondary_access_token!
        submission.update!(secondary_access_token_expires_at: 1.day.ago)

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with blank token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: '' }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with missing token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: {}.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 422 when submission is in wrong state' do
        token = submission.generate_secondary_access_token!
        submission.update!(status: 'secondary_in_progress')

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/cannot be started in its current state/)
      end

      it 'creates an InProgressForm for the secondary user' do
        token = submission.generate_secondary_access_token!

        expect do
          post "/v0/multi_party_forms/secondary/#{submission.id}/start",
               params: { token: }.to_json,
               headers: { 'CONTENT_TYPE' => 'application/json' }
        end.to change(InProgressForm, :count).by(1)

        secondary_form = InProgressForm.last
        expect(secondary_form.form_id).to eq(submission.secondary_form_id)
        expect(secondary_form.user_uuid).to eq(user.uuid.delete('-'))
        expect(secondary_form.user_account_id).to eq(user.user_account.id)
      end

      it 'updates submission with secondary user details' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        submission.reload
        expect(submission.secondary_user_uuid).to eq(user.uuid)
        expect(submission.secondary_in_progress_form).to be_present
        expect(submission.status).to eq('secondary_in_progress')
      end

      it 'increments StatsD metrics' do
        token = submission.generate_secondary_access_token!

        allow(StatsD).to receive(:increment).and_call_original
        expect(StatsD).to receive(:increment).with(
          'multi_party_form.secondary_started',
          tags: ["form_type:#{submission.form_type}"]
        )

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end

      it 'returns correct JSON structure with veteran sections as read-only' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        json_response = JSON.parse(response.body)
        expect(json_response['data']['id']).to eq(submission.id)
        expect(json_response['data']['type']).to eq('multi_party_form_submission')
        expect(json_response['data']['attributes']).to include(
          'form_type' => submission.form_type,
          'status' => 'secondary_in_progress',
          'primary_form_id' => submission.primary_form_id,
          'secondary_form_id' => submission.secondary_form_id,
          'veteran_sections' => { 'read_only' => true }
        )
        expect(json_response['data']['attributes']['created_at']).to be_present
      end

      it 'returns 404 when submission does not exist' do
        nonexistent_id = 'bad-uuid'

        post "/v0/multi_party_forms/secondary/#{nonexistent_id}/start",
             params: { token: 'some-token' }.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Record not found')
        expect(json_response['errors'].first['detail']).to match(/bad-uuid/)
      end
    end
  end
end
