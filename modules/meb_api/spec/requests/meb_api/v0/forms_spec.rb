# frozen_string_literal: true

require 'rails_helper'
require 'dgi/forms/service/submission_service'
require 'dgi/forms/service/letter_service'

RSpec.describe 'MebApi::V0 Forms', type: :request do
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

      it 'uses current user email and name when params not provided' do
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
        post '/meb_api/v0/forms_send_confirmation_email', params: { claim_status: 'ELIGIBLE' }
        expect(MebApi::V0::Submit1990emebFormConfirmation).to have_received(:perform_async)
          .with('ELIGIBLE', user.email, 'HERBERT')
      end
    end

    context 'when the feature flag is disabled' do
      it 'does not send the confirmation email' do
        allow(Flipper).to receive(:enabled?).with(:form1990emeb_confirmation_email).and_return(false)
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
        post('/meb_api/v0/forms_send_confirmation_email', params: {}, headers:)
        expect(MebApi::V0::Submit1990emebFormConfirmation).not_to have_received(:perform_async)
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when required attributes are missing' do
      before do
        allow(MebApi::V0::Submit1990emebFormConfirmation).to receive(:perform_async)
      end

      it 'does not send email when claim_status is missing' do
        post '/meb_api/v0/forms_send_confirmation_email', params: {
          email: 'test@test.com', first_name: 'test'
        }
        expect(MebApi::V0::Submit1990emebFormConfirmation).not_to have_received(:perform_async)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not send email when email is missing and user has no email' do
        user_without_email = build(:user, :loa3, user_details.merge(email: nil))
        sign_in_as(user_without_email)
        post '/meb_api/v0/forms_send_confirmation_email', params: {
          claim_status: 'ELIGIBLE', first_name: 'test'
        }
        expect(MebApi::V0::Submit1990emebFormConfirmation).not_to have_received(:perform_async)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not send email when first_name is missing and user has no first_name' do
        user_without_name = build(:user, :loa3, user_details.merge(first_name: nil))
        sign_in_as(user_without_name)
        post '/meb_api/v0/forms_send_confirmation_email', params: {
          claim_status: 'ELIGIBLE', email: 'test@test.com'
        }
        expect(MebApi::V0::Submit1990emebFormConfirmation).not_to have_received(:perform_async)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'logs warning with attribute presence info' do
        expect(Rails.logger).to receive(:warn).with(
          '1990emeb confirmation email skipped due to missing attributes',
          hash_including(
            status_present: false,
            email_present: true,
            first_name_present: true
          )
        )
        post '/meb_api/v0/forms_send_confirmation_email', params: {
          email: 'test@test.com', first_name: 'test'
        }
      end
    end
  end

  describe 'GET /meb_api/v0/forms_claim_letter' do
    let(:claimant_response) { double('claimant_response', claimant_id: 600_000_001, status: 200) }
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
      let(:claimant_response) { double('claimant_response', claimant_id: nil, status: 404, body: 'Error content') }

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

    context 'with direct deposit' do
      let(:direct_deposit_client) { instance_double(DirectDeposit::Client) }
      let(:payment_info) { { account_number: '1234', routing_number: '5678' } }

      before do
        allow(DirectDeposit::Client).to receive(:new).and_return(direct_deposit_client)
        allow(direct_deposit_client).to receive(:get_payment_info).and_return(payment_info)
      end

      it 'includes direct deposit information in submission' do
        post '/meb_api/v0/forms_submit_claim', params: {
          form: {
            direct_deposit: {
              direct_deposit_account_number: '*********1234',
              direct_deposit_routing_number: '*****5678'
            }
          }
        }
        expect(submission_service).to have_received(:submit_claim).with(
          hash_including(form: hash_including(direct_deposit: hash_including(
            direct_deposit_account_number: '*********1234'
          ))),
          payment_info
        )
        expect(response).to have_http_status(:ok)
      end

      it 'calls DirectDeposit::Client when asterisks present' do
        expect(DirectDeposit::Client).to receive(:new).with(user.icn).and_return(direct_deposit_client)
        expect(direct_deposit_client).to receive(:get_payment_info).and_return(payment_info)

        post '/meb_api/v0/forms_submit_claim', params: {
          form: {
            direct_deposit: {
              direct_deposit_account_number: '*********1234',
              direct_deposit_routing_number: '*****5678'
            }
          }
        }
        expect(response).to have_http_status(:ok)
      end

      # DirectDeposit service errors should not block claim submission.
      # Masked values are unmasked via DirectDeposit, but failures are handled gracefully.
      context 'when direct deposit service returns nil' do
        before do
          allow(direct_deposit_client).to receive(:get_payment_info).and_return(nil)
        end

        it 'proceeds with 200 OK status and logs warning' do
          expect(Rails.logger).to receive(:warn).with(
            'DirectDeposit::Client returned nil response, proceeding without direct deposit info'
          )
          post '/meb_api/v0/forms_submit_claim', params: {
            form: {
              direct_deposit: {
                direct_deposit_account_number: '*********1234',
                direct_deposit_routing_number: '*****5678'
              }
            }
          }
          expect(response).to have_http_status(:ok)
          expect(submission_service).to have_received(:submit_claim).with(
            hash_including(form: hash_including(direct_deposit: hash_including(
              direct_deposit_account_number: '*********1234'
            ))),
            nil
          )
        end
      end

      context 'when direct deposit service raises an error' do
        before do
          allow(direct_deposit_client).to receive(:get_payment_info).and_raise(StandardError.new('Service error'))
        end

        it 'proceeds with 200 OK status and logs error' do
          expect(Rails.logger).to receive(:error).with('Lighthouse direct deposit service error: Service error')
          post '/meb_api/v0/forms_submit_claim', params: {
            form: {
              direct_deposit: {
                direct_deposit_account_number: '*********1234',
                direct_deposit_routing_number: '*****5678'
              }
            }
          }
          expect(response).to have_http_status(:ok)
          expect(submission_service).to have_received(:submit_claim).with(
            hash_including(form: hash_including(direct_deposit: hash_including(
              direct_deposit_account_number: '*********1234'
            ))),
            nil
          )
        end
      end

      it 'logs error message as "Lighthouse direct deposit service error" when service fails' do
        allow(direct_deposit_client).to receive(:get_payment_info).and_raise(StandardError.new('Connection timeout'))

        expect(Rails.logger).to receive(:error).with('Lighthouse direct deposit service error: Connection timeout')

        post '/meb_api/v0/forms_submit_claim', params: {
          form: {
            direct_deposit: {
              direct_deposit_account_number: '*********1234',
              direct_deposit_routing_number: '*****5678'
            }
          }
        }
        expect(response).to have_http_status(:ok)
      end

      context 'when account number does not contain asterisks' do
        it 'does not call DirectDeposit service (optimization)' do
          expect(DirectDeposit::Client).not_to receive(:new)

          post '/meb_api/v0/forms_submit_claim', params: {
            form: {
              direct_deposit: {
                direct_deposit_account_number: '1234567890',
                direct_deposit_routing_number: '031000503'
              }
            }
          }
          expect(response).to have_http_status(:ok)
          expect(submission_service).to have_received(:submit_claim).with(
            hash_including(form: hash_including(direct_deposit: hash_including(
              direct_deposit_account_number: '1234567890'
            ))),
            nil
          )
        end
      end

      context 'when account number contains asterisks' do
        it 'calls DirectDeposit service to fetch unmasked values' do
          expect(DirectDeposit::Client).to receive(:new).with(user.icn).and_return(direct_deposit_client)
          expect(direct_deposit_client).to receive(:get_payment_info).and_return(payment_info)

          post '/meb_api/v0/forms_submit_claim', params: {
            form: {
              direct_deposit: {
                direct_deposit_account_number: '*********1234',
                direct_deposit_routing_number: '*****0503'
              }
            }
          }
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when direct_deposit fields are not present' do
        it 'does not call DirectDeposit service' do
          expect(DirectDeposit::Client).not_to receive(:new)

          post '/meb_api/v0/forms_submit_claim', params: {
            form: {
              claimant: {
                first_name: 'John'
              }
            }
          }
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'in development environment' do
      before do
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'skips DirectDeposit call even with asterisks present' do
        expect(DirectDeposit::Client).not_to receive(:new)

        post '/meb_api/v0/forms_submit_claim', params: {
          form: {
            direct_deposit: {
              direct_deposit_account_number: '*********1234',
              direct_deposit_routing_number: '*****5678'
            }
          }
        }
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when submission fails' do
      let(:error_message) { 'Submission failed' }

      context 'with a generic StandardError' do
        before do
          require 'dgi/forms/service/submission_service'
          submission_service = instance_double(MebApi::DGI::Forms::Submission::Service)
          allow_any_instance_of(MebApi::V0::FormsController)
            .to receive(:submission_service).and_return(submission_service)
          allow(submission_service).to receive(:submit_claim).and_raise(StandardError.new(error_message))
        end

        it 'logs error with ICN, error class and message (no status/body for generic errors)' do
          expect(Rails.logger).to receive(:error)
            .with('MEB Forms submit_claim failed', hash_including(
                                                     icn: user.icn,
                                                     error_class: 'StandardError',
                                                     error_message:,
                                                     request_id: kind_of(String)
                                                   ))
          allow(Rails.logger).to receive(:error)

          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(response).to have_http_status(:internal_server_error)
        end

        it 'increments attempt metric' do
          expect(StatsD).to receive(:increment).with('api.meb.submit_claim.attempt').once
          allow(StatsD).to receive(:increment)
          allow(Rails.logger).to receive(:error)

          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(response).to have_http_status(:internal_server_error)
        end

        it 'returns 500 Internal Server Error' do
          allow(Rails.logger).to receive(:error)
          allow(Rails.logger).to receive(:info)

          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(response).to have_http_status(:internal_server_error)
        end
      end

      context 'with DGI service ClientError (downstream service failure)' do
        let(:error_body) { { timestamp: '2025-01-14', status: 500, error: 'Internal service error' }.to_json }
        let(:client_error) do
          Common::Client::Errors::ClientError.new('DGI service error', 500, error_body)
        end

        before do
          require 'dgi/forms/service/submission_service'
          submission_service = instance_double(MebApi::DGI::Forms::Submission::Service)
          allow_any_instance_of(MebApi::V0::FormsController)
            .to receive(:submission_service).and_return(submission_service)
          allow(submission_service).to receive(:submit_claim).and_raise(client_error)
        end

        it 'logs error with DGI HTTP status and response body for troubleshooting' do
          expect(Rails.logger).to receive(:error)
            .with('MEB Forms submit_claim failed', hash_including(
                                                     icn: user.icn,
                                                     error_class: 'Common::Client::Errors::ClientError',
                                                     error_message: 'DGI service error',
                                                     status: 500,
                                                     response_body: error_body,
                                                     request_id: kind_of(String)
                                                   ))
          allow(Rails.logger).to receive(:error)
          allow(StatsD).to receive(:increment)

          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(response).to have_http_status(:service_unavailable)
        end

        it 'returns 503 Service Unavailable (breakers converts ClientError to ServiceOutage)' do
          allow(Rails.logger).to receive(:error)
          allow(StatsD).to receive(:increment)

          post '/meb_api/v0/forms_submit_claim', params: { test_param: 'value' }
          expect(response).to have_http_status(:service_unavailable)
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
          claimant_id: 600_000_001,
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
