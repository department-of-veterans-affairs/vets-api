# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MultiPartyForms::Secondary', type: :request do
  include StatsD::Instrument::Helpers

  let(:user) { create(:user, :loa3) }
  let(:submission) do
    create(
      :multi_party_form_submission,
      :with_secondary,
      status: 'awaiting_secondary_start'
    )
  end

  describe 'GET /v0/multi_party_forms/secondary/:id' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get "/v0/multi_party_forms/secondary/#{submission.id}"

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
        get "/v0/multi_party_forms/secondary/#{submission.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated and feature flag enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_2680_multi_party_forms_enabled, anything).and_return(true)
      end

      context 'when submission belongs to the authenticated user' do
        let(:submission) do
          create(
            :multi_party_form_submission,
            :with_secondary,
            status: 'secondary_in_progress',
            secondary_user_uuid: user.uuid
          )
        end

        it 'returns the submission with Veteran and physician sections' do
          get "/v0/multi_party_forms/secondary/#{submission.id}"

          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to eq(submission.id)
          expect(json_response['data']['type']).to eq('multi_party_form_submission')
          expect(json_response['data']['attributes']['status']).to eq('secondary_in_progress')
          expect(json_response['data']['attributes']['veteran_sections']).to include('read_only' => true)
          expect(json_response['data']['attributes']['physician_sections']).to include('editable' => true)
        end

        it 'includes form data in Veteran and physician sections' do
          primary_form = submission.primary_in_progress_form
          primary_form.update!(form_data: { veteran_name: 'John Doe' }.to_json)

          get "/v0/multi_party_forms/secondary/#{submission.id}"

          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          veteran_data = json_response['data']['attributes']['veteran_sections']['data']
          physician_data = json_response['data']['attributes']['physician_sections']['data']

          expect(veteran_data).to eq({ 'veteran_name' => 'John Doe' })
          expect(physician_data).to eq({})
        end
      end

      context 'when form data contains invalid JSON' do
        let(:submission) do
          create(
            :multi_party_form_submission,
            :with_secondary,
            status: 'secondary_in_progress',
            secondary_user_uuid: user.uuid
          )
        end

        it 'handles JSON parse errors gracefully and returns empty hash' do
          primary_form = submission.primary_in_progress_form
          # Need to bypass validations to set invalid JSON for testing error handling
          primary_form.update_column(:form_data, 'invalid json {') # rubocop:disable Rails/SkipsModelValidations

          get "/v0/multi_party_forms/secondary/#{submission.id}"

          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['data']['attributes']['veteran_sections']['data']).to eq({})
        end
      end

      context 'when submission belongs to another user' do
        let(:other_user_submission) do
          create(
            :multi_party_form_submission,
            :with_secondary,
            status: 'secondary_in_progress',
            secondary_user_uuid: SecureRandom.uuid
          )
        end

        it 'returns not found' do
          get "/v0/multi_party_forms/secondary/#{other_user_submission.id}"

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when submission does not exist' do
        it 'returns not found' do
          nonexistent_id = SecureRandom.uuid

          get "/v0/multi_party_forms/secondary/#{nonexistent_id}"

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'POST /v0/multi_party_forms/secondary/:id/start' do
    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'Content-Type' => 'application/json' }

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
             headers: { 'Content-Type' => 'application/json' }

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

        metrics = capture_statsd_calls do
          post "/v0/multi_party_forms/secondary/#{submission.id}/start",
               params: { token: }.to_json,
               headers: { 'Content-Type' => 'application/json' }
        end

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response['data']['type']).to eq('multi_party_form_submission')
        expect(json_response['data']['attributes']['status']).to eq('secondary_in_progress')

        expect(metrics.collect(&:source)).to include(
          'multi_party_form.secondary.start.success:1|c|#form_type:21-2680'
        )
      end

      it 'returns 403 forbidden with invalid token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: 'invalid-token' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with expired token' do
        token = submission.generate_secondary_access_token!
        submission.update!(secondary_access_token_expires_at: 1.day.ago)

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with blank token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: '' }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 403 forbidden with missing token' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: {}.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:forbidden)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/access token is invalid or has expired/)
      end

      it 'returns 422 when submission is in wrong state' do
        token = submission.generate_secondary_access_token!
        submission.update!(status: 'secondary_in_progress')

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['detail']).to match(/cannot be started in its current state/)
      end

      it 'creates an InProgressForm for the secondary user' do
        token = submission.generate_secondary_access_token!

        expect do
          post "/v0/multi_party_forms/secondary/#{submission.id}/start",
               params: { token: }.to_json,
               headers: { 'Content-Type' => 'application/json' }
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
             headers: { 'Content-Type' => 'application/json' }

        submission.reload
        expect(submission.secondary_user_uuid).to eq(user.uuid)
        expect(submission.secondary_in_progress_form).to be_present
        expect(submission.status).to eq('secondary_in_progress')
      end

      it 'returns correct JSON structure with Veteran sections as read-only' do
        token = submission.generate_secondary_access_token!

        post "/v0/multi_party_forms/secondary/#{submission.id}/start",
             params: { token: }.to_json,
             headers: { 'Content-Type' => 'application/json' }

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
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Record not found')
        expect(json_response['errors'].first['detail']).to match(/bad-uuid/)
      end
    end
  end

  describe 'POST /v0/multi_party_forms/secondary/:id/complete' do
    let(:submission) do
      create(
        :multi_party_form_submission,
        :with_secondary,
        status: 'secondary_in_progress',
        secondary_user_uuid: user.uuid
      )
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
             headers: { 'Content-Type' => 'application/json' }

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
        post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
             headers: { 'Content-Type' => 'application/json' }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when authenticated and feature flag enabled' do
      before do
        sign_in_as(user)
        allow(Flipper).to receive(:enabled?).and_call_original
        allow(Flipper).to receive(:enabled?).with(:form_2680_multi_party_forms_enabled, anything).and_return(true)
      end

      context 'with valid state' do
        it 'completes the secondary submission and transitions to submitted' do
          metrics = capture_statsd_calls do
            post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(response).to have_http_status(:ok)

          json_response = JSON.parse(response.body)
          expect(json_response['data']['id']).to eq(submission.id)
          expect(json_response['data']['type']).to eq('multi_party_form_submission')
          expect(json_response['data']['attributes']['status']).to eq('submitted')
          expect(json_response['data']['attributes']['secondary_completed_at']).to be_present
          expect(json_response['data']['attributes']['message']).to eq('Secondary form completed successfully')

          expect(metrics.collect(&:source)).to include(
            'multi_party_form.secondary.complete.success:1|c|#form_type:21-2680'
          )
        end

        it 'updates secondary_completed_at timestamp' do
          post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
               headers: { 'Content-Type' => 'application/json' }

          submission.reload
          expect(submission.secondary_completed_at).to be_present
          expect(submission.status).to eq('submitted')
        end
      end

      context 'with form_data' do
        let(:form_data) { { physician_notes: 'Patient is recovering well' } }
        let(:secondary_form) do
          create(
            :in_progress_form,
            form_id: submission.secondary_form_id,
            user_uuid: user.uuid
          )
        end

        before do
          submission.update!(secondary_in_progress_form: secondary_form)
        end

        it 'updates the secondary InProgressForm with form_data' do
          post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
               params: { form_data: }.to_json,
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:ok)

          submission.reload
          expect(submission.secondary_in_progress_form.form_data).to eq(form_data.to_json)
        end

        it 'returns 500 and tracks failure metric when secondary_in_progress_form is missing' do
          submission.update!(secondary_in_progress_form_id: nil)

          metrics = capture_statsd_calls do
            post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
                 params: { form_data: }.to_json,
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(response).to have_http_status(:internal_server_error)
          expect(metrics.collect(&:source)).to include(
            'multi_party_form.secondary.complete.failure:1|c|#form_type:21-2680'
          )
        end
      end

      context 'when submission is in wrong state' do
        before { submission.update!(status: 'awaiting_secondary_start') }

        it 'returns 422 unprocessable entity' do
          post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:unprocessable_entity)

          json_response = JSON.parse(response.body)
          expect(json_response['errors'].first['title']).to eq('Unprocessable Entity')
          expect(json_response['errors'].first['detail']).to match(/must be in secondary_in_progress state/)
        end
      end

      context 'when submission belongs to another user' do
        let(:other_user_submission) do
          create(
            :multi_party_form_submission,
            :with_secondary,
            status: 'secondary_in_progress',
            secondary_user_uuid: SecureRandom.uuid
          )
        end

        it 'returns not found' do
          post "/v0/multi_party_forms/secondary/#{other_user_submission.id}/complete",
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when submission does not exist' do
        it 'returns not found' do
          post "/v0/multi_party_forms/secondary/#{SecureRandom.uuid}/complete",
               headers: { 'Content-Type' => 'application/json' }

          expect(response).to have_http_status(:not_found)
        end
      end

      context 'when unexpected error occurs' do
        it 'handles error and tracks failure metric' do
          allow_any_instance_of(MultiPartyFormSubmission).to receive(:secondary_complete!)
            .and_raise(StandardError, 'Unexpected error')

          metrics = capture_statsd_calls do
            post "/v0/multi_party_forms/secondary/#{submission.id}/complete",
                 headers: { 'Content-Type' => 'application/json' }
          end

          expect(response).to have_http_status(:internal_server_error)
          expect(metrics.collect(&:source)).to include(
            'multi_party_form.secondary.complete.failure:1|c|#form_type:21-2680'
          )
        end
      end
    end
  end
end
