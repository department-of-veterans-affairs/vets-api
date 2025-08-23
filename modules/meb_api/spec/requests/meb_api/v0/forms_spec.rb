# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/submission_service'
require 'dgi/forms/service/letter_service'

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
    Flipper.enable(:show_forms_app)
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

      it 'uses current user email and name when params not provided' do
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
        post '/meb_api/v0/forms_send_confirmation_email', params: { claim_status: 'ELIGIBLE' }
        expect(MebApi::V0::Submit1990emebFormConfirmation).to have_received(:perform_async)
          .with('ELIGIBLE', user.email, 'HERBERT')
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

  describe 'GET /meb_api/v0/forms_claim_letter' do
    let(:claimant_response) { double('claimant_response', :[] => 600_000_001, status: 200) }
    let(:claim_status_response) { double('claim_status_response', claim_status: 'ELIGIBLE') }
    let(:letter_response) { double('letter_response', body: 'PDF content here', status: 200) }
    let(:claimant_service) { instance_double(MebApi::DGI::Claimant::Service) }
    let(:status_service) { instance_double(MebApi::DGI::Status::Service) }
    let(:letter_service) { instance_double(MebApi::DGI::Forms::Letters::Service) }

    before do
      allow(MebApi::DGI::Claimant::Service).to receive(:new).and_return(claimant_service)
      allow(MebApi::DGI::Status::Service).to receive(:new).and_return(status_service)
      allow(MebApi::DGI::Forms::Letters::Service).to receive(:new).and_return(letter_service)
      allow(claimant_service).to receive(:get_claimant_info).and_return(claimant_response)
      allow(status_service).to receive(:get_claim_status).and_return(claim_status_response)
      allow(letter_service).to receive(:get_claim_letter).and_return(letter_response)
    end

    context 'when claimant is eligible' do
      it 'returns a PDF with eligible filename' do
        travel_to Time.zone.local(2024, 1, 15, 10, 30, 0) do
          get '/meb_api/v0/forms_claim_letter', params: { type: 'ToeSubmission' }
          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include('Post-9%2F11 GI_Bill_CoE')
        end
      end
    end

    context 'when claimant is not eligible' do
      let(:claim_status_response) { double('claim_status_response', claim_status: 'DENIED') }

      it 'returns a PDF with denial filename' do
        travel_to Time.zone.local(2024, 1, 15, 10, 30, 0) do
          get '/meb_api/v0/forms_claim_letter', params: { type: 'ToeSubmission' }
          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include('Post-9%2F11 GI_Bill_Denial')
        end
      end
    end

    context 'when claimant response is invalid' do
      let(:claimant_response) { double('claimant_response', :[] => nil, status: 404, body: 'Error content') }

      it 'returns claimant error response' do
        get '/meb_api/v0/forms_claim_letter', params: { type: 'ToeSubmission' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq('Error content')
      end
    end
  end

  describe 'POST /meb_api/v0/forms_submit_claim' do
    let(:submission_service) { instance_double(MebApi::DGI::Forms::Submission::Service) }
    let(:submission_response) { double('submission_response', status: 200) }

    before do
      allow(MebApi::DGI::Forms::Submission::Service).to receive(:new).and_return(submission_service)
      allow(submission_service).to receive(:submit_claim).and_return(submission_response)
    end

    context 'when submitting a claim without direct deposit feature' do
      it 'successfully submits the claim' do
        post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['data']['status']).to eq(200)
      end
    end

    context 'when submitting with form_id to clear saved form' do
      it 'clears the saved form after submission' do
        expect_any_instance_of(MebApi::V0::FormsController).to receive(:clear_saved_form).with('12345')
        post '/meb_api/v0/forms_submit_claim', params: { form_id: '12345' }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when direct deposit feature is enabled' do
      let(:direct_deposit_client) { instance_double(DirectDeposit::Client) }
      let(:payment_info) { { account_number: '1234', routing_number: '5678' } }

      before do
        Flipper.enable(:toe_light_house_dgi_direct_deposit)
        allow(DirectDeposit::Client).to receive(:new).and_return(direct_deposit_client)
        allow(direct_deposit_client).to receive(:get_payment_info).and_return(payment_info)
      end

      after do
        Flipper.disable(:toe_light_house_dgi_direct_deposit)
      end

      it 'includes direct deposit information in submission' do
        post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
        expect(submission_service).to have_received(:submit_claim).with(
          hash_including(test_param: 'value'),
          payment_info
        )
        expect(response).to have_http_status(:ok)
      end

      context 'when direct deposit service returns nil' do
        before do
          allow(direct_deposit_client).to receive(:get_payment_info).and_return(nil)
        end

        it 'proceeds without direct deposit info and logs warning' do
          expect(Rails.logger).to receive(:warn).with(
            'DirectDeposit::Client returned nil response, proceeding without direct deposit info'
          )
          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(submission_service).to have_received(:submit_claim).with(
            hash_including(test_param: 'value'),
            nil
          )
        end
      end

      context 'when direct deposit service raises an error' do
        before do
          allow(direct_deposit_client).to receive(:get_payment_info).and_raise(StandardError.new('Service error'))
        end

        it 'logs error and proceeds without direct deposit info' do
          expect(Rails.logger).to receive(:error).with('BIS service error: Service error')
          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(submission_service).to have_received(:submit_claim).with(
            hash_including(test_param: 'value'),
            nil
          )
        end
      end
    end
  end

  describe 'GET /meb_api/v0/forms_claim_status with error cases' do
    require 'dgi/claimant/service'
    require 'dgi/status/service'

    let(:claimant_service) { instance_double(MebApi::DGI::Claimant::Service) }
    let(:status_service) { instance_double(MebApi::DGI::Status::Service) }

    before do
      allow(MebApi::DGI::Claimant::Service).to receive(:new).and_return(claimant_service)
      allow(MebApi::DGI::Status::Service).to receive(:new).and_return(status_service)
    end

    context 'when claimant response has error status' do
      let(:claimant_response) do
        double(
          'claimant_response',
          :[] => 600_000_001,
          status: 500,
          body: { error: 'Internal error' },
          claimant: nil,
          service_data: nil,
          toe_sponsors: nil
        )
      end
      let(:claim_status_response) { double('claim_status_response', claim_status: 'ELIGIBLE', status: 200) }

      before do
        allow(claimant_service).to receive(:get_claimant_info).and_return(claimant_response)
        allow(status_service).to receive(:get_claim_status).and_return(claim_status_response)
      end

      it 'returns ToeClaimantInfoSerializer for invalid claimant response' do
        expect(ToeClaimantInfoSerializer).to receive(:new).with(claimant_response).and_call_original
        get '/meb_api/v0/forms_claim_status', params: { type: 'ToeSubmission' }
        expect(response).to have_http_status(:ok)
        # Response serializes the claimant response since it has an error status
      end
    end
  end
end
