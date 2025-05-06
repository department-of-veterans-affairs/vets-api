# frozen_string_literal: true

require 'rails_helper'

Rspec.describe 'MebApi::V0 Forms', type: :request do
  include SchemaMatchers
  include ActiveSupport::Testing::TimeHelpers

  VCR.configure do |config|
    config.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end
  end

  let(:user_details) do
    {
      first_name: 'Herbert',
      last_name: 'Hoover',
      middle_name: '',
      birth_date: '1970-01-01',
      ssn: '796121200'
    }
  end

  let(:claimant_id) { 1 }
  let(:user) { build(:user, :loa3, user_details) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    sign_in_as(user)
  end

  describe 'POST /meb_api/v0/forms_sponsors' do
    context 'Retrieves sponsors for Toes' do
      it 'returns a 200 status' do
        VCR.use_cassette('dgi/forms/sponsor_toes') do
          post '/meb_api/v0/forms_sponsors'
          expect(response).to have_http_status(:ok)
        end
      end
    end

    # @NOTE: This is commented out as we've removed the form_type param from the controller.
    # Once that is added back this test is valid.
    # context 'Retrieves sponsors for FryDea' do
    #   it 'returns a 200 status' do
    #     VCR.use_cassette('dgi/forms/sponsor_fry_dea') do
    #       post '/meb_api/v0/forms_sponsors', params: { 'form_type': 'FryDea' }
    #       expect(response).to have_http_status(:ok)
    #     end
    #   end
    # end
  end

  describe 'GET /meb_api/v0/forms_claimant_info' do
    context 'Looks up veteran in LTS' do
      it 'returns a 200 status with toe claimant info' do
        VCR.use_cassette('dgi/post_toe_claimant_info') do
          get '/meb_api/v0/forms_claimant_info'
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('dgi/toe_claimant_info_response', { strict: false })
        end
      end

      it 'returns a claimant info 200 status with type as a parameter' do
        VCR.use_cassette('dgi/post_chapter35_claimant_info') do
          get '/meb_api/v0/forms_claimant_info', params: { type: 'chapter35' }
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('dgi/toe_claimant_info_response', { strict: false })
        end
      end
    end
  end

  describe 'GET /meb_api/v0/forms_claim_status' do
    context 'when polling for a claimant id' do
      it 'handles a request when the claimant has not been created yet' do
        VCR.use_cassette('dgi/polling_with_race_condition') do
          get '/meb_api/v0/forms_claim_status', params: { type: 'ToeSubmission' }
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['claimStatus']).to eq('INPROGRESS')
        end
      end

      it 'handles a request when the claimant has been created' do
        VCR.use_cassette('dgi/polling_without_race_condition') do
          get '/meb_api/v0/forms_claim_status', params: { type: 'ToeSubmission' }
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['attributes']['claimant_id']).to eq(600_000_001)
        end
      end
    end
  end

  describe 'POST /meb_api/v0/forms_send_confirmation_email' do
    context 'when the feature flag is enabled' do
      it 'sends the confirmation email with provided name and email params' do
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
        post '/meb_api/v0/forms_send_confirmation_email', params: {
          claim_status: 'ELIGIBLE', email: 'test@test.com', first_name: 'test'
        }
        expect(MebApi::V0::Submit1990emebFormConfirmation).to have_received(:perform_async)
          .with('ELIGIBLE', 'test@test.com', 'TEST')
      end
    end

    context 'when the feature flag is disabled' do
      it 'does not send the confirmation email' do
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
        Flipper.disable(:form1990emeb_confirmation_email)
        post('/meb_api/v0/forms_send_confirmation_email', params: {}, headers:)
        expect(MebApi::V0::Submit1990emebFormConfirmation).not_to have_received(:perform_async)
        expect(response).to have_http_status(:no_content)
        Flipper.enable(:form1990emeb_confirmation_email)
      end
    end
  end
end
