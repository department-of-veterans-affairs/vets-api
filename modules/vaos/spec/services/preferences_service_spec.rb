# frozen_string_literal: true

require 'rails_helper'

describe VAOS::PreferencesService do
  let(:user) { build(:user, :mhv) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_preferences' do
    context 'with a 200 response' do
      it 'includes' do
        VCR.use_cassette('vaos/preferences/get_preferences', match_requests_on: %i[method uri]) do
          response = subject.get_preferences(user)
          expect(response.notification_frequency).to eq('Never')
          expect(response.email_allowed).to be_truthy
          expect(response.email_address).to eq('abraham.lincoln@va.gov')
          expect(response.text_msg_allowed).to be_falsey
        end
      end
    end
  end

  describe '#put_preferences' do
    context 'with valid params' do
        it 'updates preferences', :skip_mvi do
          VCR.use_cassette('vaos/preferences/put_preference', record: :new_episodes) do
            put "/v0/vaos/preferences", params: request_body

            expect(response).to have_http_status(:success)
            expect(response.body).to be_a(String)
            expect(json_body_for(response)).to match_schema('vaos/put_preference')
          end
        end
      end

      context 'with invalid params' do
        it 'returns a validation error', :skip_mvi do
          put "/v0/vaos/preferences", params: request_body

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to be_a(String)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('')
        end
      end
  end
end
