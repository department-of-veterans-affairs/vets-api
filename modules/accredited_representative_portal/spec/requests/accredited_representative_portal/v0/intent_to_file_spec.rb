# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::IntentToFileController, type: :request do
  let(:test_user) { create(:representative_user, email: 'j2@example.com') }
  let(:time) { '2024-12-21T04:45:37.458Z' }

  before do
    Settings.add_source!({
                           'accredited_representative_portal' => {
                             'pilot_user_email_poa_codes' => { 'j2@example.com' => ['067'] }
                           }
                         })
    Settings.reload!
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
    login_as(test_user)
    travel_to(time)
  end

  describe 'GET /accredited_representative_portal/v0/intent_to_file' do
    context 'feature flag is off' do
      it 'returns forbidden' do
        Flipper.disable(:accredited_representative_portal_intent_to_file_api)
        get('/accredited_representative_portal/v0/intent_to_file/123498767V234859')
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'bad or missing filing type' do
      it 'returns the appropriate error message' do
        get('/accredited_representative_portal/v0/intent_to_file/123498767V234859')
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'rep does not have POA for veteran' do
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }

      it 'returns 403' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'rep has filed ITF' do
      it 'returns existing ITF filing for current user' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
            get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['data']['id']).to eq('193685')
          end
        end
      end
    end
  end

  describe 'POST /accredited_representative_portal/v0/intent_to_file' do
    context 'happy path' do
      it 'submits an intent to file' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
            post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
            expect(response).to have_http_status(:created)
            expect(JSON.parse(response.body).dig('data', 'id')).to eq '193685'
            expect(JSON.parse(response.body).dig('data', 'attributes', 'status')).to eq 'active'
          end
        end
      end
    end

    context 'rep does not have POA for veteran' do
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }

      it 'returns 403' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'unprocessable entity' do
      it 'returns a 422' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_422_response') do
            post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
            expect(response).to have_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context 'timeout from lighthouse submission' do
      it 'returns a 503' do
        VCR.use_cassette('lighthouse/benefits_claims/power_of_attorney/200_response') do
          VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_503_response') do
            post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
            expect(response).to have_http_status(:service_unavailable)
          end
        end
      end
    end
  end
end
