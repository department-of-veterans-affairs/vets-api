# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointment request messages', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET messages' do
    let(:request_id) { '8a4886886e4c8e22016e5bee49c30007' }

    context 'loa1 user with flipper enabled' do
      let(:current_user) { build(:user, :loa1) }

      it 'does not have access' do
        get "/v0/vaos/appointment_requests/#{request_id}/messages"
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'loa3 user' do
      let(:current_user) { build(:user, :vaos) }

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          get "/v0/vaos/appointment_requests/#{request_id}/messages"
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      it 'has access and returns messages', :skip_mvi do
        VCR.use_cassette('vaos/messages/get_messages', match_requests_on: %i[method uri]) do
          get "/v0/vaos/appointment_requests/#{request_id}/messages"

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('vaos/messages')
        end
      end
    end
  end

  describe 'POST message' do
    let(:request_id) { '8a4886886e4c8e22016ef6a8b1bf0396' }
    let(:request_body) { { message_text: 'I want to see doctor Jeckyl please.' } }

    context 'loa1 user with flipper enabled' do
      let(:current_user) { build(:user, :loa1) }

      it 'does not have access' do
        post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'loa3 user' do
      let(:current_user) { build(:user, :vaos) }

      context 'with flipper disabled' do
        it 'does not have access' do
          Flipper.disable('va_online_scheduling')
          post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      context 'with access and valid message' do
        it 'posts a message', :skip_mvi do
          VCR.use_cassette('vaos/messages/post_message', match_requests_on: %i[method uri]) do
            post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

            expect(response).to have_http_status(:success)
            expect(response.body).to be_a(String)
            expect(json_body_for(response)).to match_schema('vaos/message')
          end
        end
      end

      context 'with access and invalid message' do
        let(:request_body) { { message_text: Faker::Lorem.characters(number: 101) } }

        it 'returns a validation error', :skip_mvi do
          post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('message-text - is too long (maximum is 100 characters)')
        end
      end

      context 'with access and invalid message' do
        let(:request_body) { { message_text: '' } }

        it 'returns a validation error', :skip_mvi do
          post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

          expect(response).to have_http_status(:bad_request)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('The required parameter "message_text", is missing')
        end
      end

      context 'with access and invalid appointment request id' do
        let(:request_id) { '8a4886886e4c8e22016eebd3b8820347' }

        it 'returns bad request', :skip_mvi do
          VCR.use_cassette('vaos/messages/post_message_error', match_requests_on: %i[method uri]) do
            post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

            expect(response).to have_http_status(:bad_request)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('Appointment request id is invalid')
          end
        end
      end

      context 'with access and too many messages for appointment request' do
        it 'returns bad request', :skip_mvi do
          VCR.use_cassette('vaos/messages/post_message_error_400', match_requests_on: %i[method uri]) do
            post "/v0/vaos/appointment_requests/#{request_id}/messages", params: request_body

            expect(response).to have_http_status(:bad_request)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('Maximum allowed number of messages for this appointment request reached.')
          end
        end
      end
    end
  end
end
