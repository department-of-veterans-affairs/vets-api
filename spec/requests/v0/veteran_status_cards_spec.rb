# frozen_string_literal: true

require 'rails_helper'
require 'veteran_status_card/service'

RSpec.describe 'V0::VeteranStatusCards', type: :request do
  let(:user) { create(:user, :loa3) }

  describe 'GET /v0/veteran_status_card' do
    context 'when not logged in' do
      it 'returns unauthorized' do
        get '/v0/veteran_status_card'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in' do
      before { sign_in_as(user) }

      context 'when veteran is eligible' do
        let(:eligible_response) do
          {
            confirmed: true,
            full_name: { first: 'John', middle: nil, last: 'Doe', suffix: nil },
            user_percent_of_disability: 50,
            latest_service_history: {
              branch_of_service: 'Army',
              latest_service_date_range: {
                begin_date: '2010-01-01',
                end_date: '2015-12-31'
              }
            }
          }
        end

        before do
          allow_any_instance_of(VeteranStatusCard::Service).to receive(:status_card).and_return(eligible_response)
        end

        it 'returns a successful response' do
          get '/v0/veteran_status_card'

          expect(response).to have_http_status(:ok)
        end

        it 'returns the expected data structure' do
          get '/v0/veteran_status_card'

          json = JSON.parse(response.body)
          expect(json['confirmed']).to be true
          expect(json['full_name']).to be_present
          expect(json['user_percent_of_disability']).to eq(50)
          expect(json['latest_service_history']).to be_present
        end
      end

      context 'when veteran is not eligible' do
        let(:ineligible_response) do
          {
            confirmed: false,
            title: 'Error Title',
            message: 'Error message',
            status: 'error'
          }
        end

        before do
          allow_any_instance_of(VeteranStatusCard::Service).to receive(:status_card).and_return(ineligible_response)
        end

        it 'returns a successful response with error details' do
          get '/v0/veteran_status_card'

          expect(response).to have_http_status(:ok)
        end

        it 'returns the error data structure' do
          get '/v0/veteran_status_card'

          json = JSON.parse(response.body)
          expect(json['confirmed']).to be false
          expect(json['title']).to eq('Error Title')
          expect(json['message']).to eq('Error message')
          expect(json['status']).to eq('error')
        end
      end

      context 'when service raises an error' do
        before do
          allow_any_instance_of(VeteranStatusCard::Service).to receive(:status_card)
            .and_raise(StandardError.new('Unexpected error'))
        end

        it 'returns an internal server error' do
          get '/v0/veteran_status_card'

          expect(response).to have_http_status(:internal_server_error)
        end
      end
    end
  end
end
