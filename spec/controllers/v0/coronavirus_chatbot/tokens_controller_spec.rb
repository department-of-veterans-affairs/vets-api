# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::CoronavirusChatbot::TokensController, type: :controller do
  describe '#create' do
    let(:locale) { 'en-US' }

    context 'when external service is healthy' do
      let(:user_id) { SecureRandom.hex(8) }
      let(:recorded_token) do
        'ew0KICAiYWxnIjogIlJTMjU2IiwNCiAgImtpZCI6ICJBT08tZXhGd2puR3lDTEJhOTgwVkxOME1tUTgiLA0KICAieDV0IjogIkFPTy1leEZ3' \
          'am5HeUNMQmE5ODBWTE4wTW1ROCIsDQogICJ0eXAiOiAiSldUIg0KfQ.ew0KICAiYm90IjogImF6Y2N0b2xhYmhlYWx0aGJvdC1kamVvZXh' \
          'jIiwNCiAgInNpdGUiOiAiUHh4SzRLa083aVkiLA0KICAiY29udiI6ICJhR09FRG1QNVFjSVFET1ZKd1F1VXotZCIsDQogICJuYmYiOiAxN' \
          'Tg3MDcwNTYwLA0KICAiZXhwIjogMTU4NzA3NDE2MCwNCiAgImlzcyI6ICJodHRwczovL2RpcmVjdGxpbmUuYm90ZnJhbWV3b3JrLmNvbS8' \
          'iLA0KICAiYXVkIjogImh0dHBzOi8vZGlyZWN0bGluZS5ib3RmcmFtZXdvcmsuY29tLyINCn0.tCn9kTNI3YOwyk5SouVMuc9WlK60RMnOC' \
          '-zn3g6ztnX1E1IDNfd2GmhDZIDfgB4VUWKC-6pRYJPhjGQqYEHbhbOhAB3avvFr81i_A2KyFiYKF-KCsl-4ACGiet6tV7RUNfkeUtqnJEp' \
          'B_-Z8cpB2Tv3BMCk6fJqHW53h7X0rIyRXlDS6CymY6qypQwkh1RQGgVR62C7X_RdVp1JQdSynYuecxc9un3adY-lEwku-AbLhWv-fxRT9O' \
          'nxb-nQf-6RtLOAaWNfhzBR3lmCABHiTyuILsg-qP-b3kagfWQuNd10Sw3eK3NuXzDjFns6Bpv9mZz6-pshYgwXkJJlTNb8Qzw'
      end
      let(:directline_uri) { Settings.coronavirus_chatbot.directline_uri }

      before do
        expect(directline_uri).not_to be_nil
        allow(SecureRandom).to receive(:hex).and_return(user_id)
      end

      it 'issues a jwt' do
        VCR.use_cassette('coronavirus_chatbot/chat_bot/healthy') do
          post :create, params: { locale: locale }
        end
        expect(response).to have_http_status(:ok)

        token_data = parse_jwt_data(response.body)

        expect(token_data['userId']).to eq user_id
        expect(token_data['locale']).to eq locale
        expect(token_data['directLineURI']).to eq directline_uri
        expect(token_data['connectorToken']).to eq recorded_token
      end
    end

    context 'when external service is not healthy' do
      before do
        expect(controller).to receive(:log_exception_to_sentry)
      end

      it 'returns service not available status' do
        VCR.use_cassette('coronavirus_chatbot/chat_bot/unhealthy') do
          post :create, params: { locale: locale }
        end

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  def parse_jwt_data(_response_body)
    token = JSON.parse(response.body)['token']
    decoded_token = JWT.decode token, Settings.coronavirus_chatbot.app_secret, true
    decoded_token.first
  end
end
