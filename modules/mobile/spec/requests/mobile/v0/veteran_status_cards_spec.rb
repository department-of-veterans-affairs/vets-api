# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require 'mobile/v0/veteran_status_card/service'

RSpec.describe 'Mobile::V0::VeteranStatusCards', type: :request do
  let!(:user) { sis_user }

  before do
    sign_in_as(user)
  end

  describe 'GET /mobile/v0/veteran_status_card' do
    it 'uses the Mobile::V0::VeteranStatusCard::Service' do
      mock_service = instance_double(Mobile::V0::VeteranStatusCard::Service)
      allow(mock_service).to receive(:status_card).and_return({ type: 'veteran_status_card' })
      expect(Mobile::V0::VeteranStatusCard::Service).to receive(:new).and_return(mock_service)

      get '/mobile/v0/veteran_status_card', headers: sis_headers

      expect(response).to have_http_status(:ok)
    end

    context 'when veteran is eligible' do
      let(:eligible_response) do
        {
          type: 'veteran_status_card',
          attributes: {
            full_name: 'John Doe',
            disability_rating: 50,
            edipi: '1234567890',
            veteran_status: 'confirmed',
            not_confirmed_reason: nil,
            service_summary_code: 'A1'
          }
        }
      end

      before do
        allow_any_instance_of(Mobile::V0::VeteranStatusCard::Service).to receive(:status_card)
          .and_return(eligible_response)
      end

      it 'returns a successful response' do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns the expected data structure', :skip_json_api_validation do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        json = response.parsed_body
        expect(json['type']).to eq('veteran_status_card')
        expect(json['attributes']['full_name'] || json['attributes']['fullName']).to be_present
        expect(json['attributes']['disability_rating'] || json['attributes']['disabilityRating']).to eq(50)
        expect(json['attributes']['veteran_status'] || json['attributes']['veteranStatus']).to eq('confirmed')
      end
    end

    context 'when veteran is not eligible' do
      let(:ineligible_response) do
        {
          type: 'veteran_status_alert',
          attributes: {
            header: 'Error Title',
            body: 'Error message',
            alert_type: 'error',
            veteran_status: 'not confirmed',
            not_confirmed_reason: 'PERSON_NOT_FOUND',
            service_summary_code: 'A1'
          }
        }
      end

      before do
        allow_any_instance_of(Mobile::V0::VeteranStatusCard::Service).to receive(:status_card)
          .and_return(ineligible_response)
      end

      it 'returns a successful response with error details' do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(response).to have_http_status(:ok)
      end

      it 'returns the error data structure', :skip_json_api_validation do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        json = response.parsed_body
        expect(json['type']).to eq('veteran_status_alert')
        expect(json['attributes']['header']).to eq('Error Title')
        expect(json['attributes']['body']).to eq('Error message')
        expect(json['attributes']['alert_type'] || json['attributes']['alertType']).to eq('error')
        expect(json['attributes']['veteran_status'] || json['attributes']['veteranStatus']).to eq('not confirmed')
      end
    end

    context 'when service raises an error' do
      before do
        allow_any_instance_of(Mobile::V0::VeteranStatusCard::Service).to receive(:status_card)
          .and_raise(StandardError.new('Unexpected error'))
      end

      it 'returns an internal server error' do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(response).to have_http_status(:internal_server_error)
      end

      it 'returns an error message in the response body', :skip_json_api_validation do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        json = response.parsed_body
        expect(json['error']).to eq('An unexpected error occurred')
      end

      it 'logs the error with backtrace' do
        allow(Rails.logger).to receive(:error)

        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(Rails.logger).to have_received(:error).with(
          'Mobile::VeteranStatusCardsController unexpected error: Unexpected error',
          hash_including(:backtrace)
        )
      end
    end

    context 'when service raises an argument error' do
      before do
        allow(Mobile::V0::VeteranStatusCard::Service).to receive(:new)
          .and_raise(ArgumentError.new('this is an argument error'))
      end

      it 'returns an argument error' do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an argument error message in the response body' do
        get '/mobile/v0/veteran_status_card', headers: sis_headers

        json = JSON.parse(response.body)
        expect(json['error']).to eq('An argument error occurred')
      end

      it 'logs the error with backtrace' do
        allow(Rails.logger).to receive(:error)

        get '/mobile/v0/veteran_status_card', headers: sis_headers

        expect(Rails.logger).to have_received(:error).with(
          'Mobile::VeteranStatusCardsController argument error: this is an argument error',
          hash_including(:backtrace)
        )
      end
    end
  end
end
