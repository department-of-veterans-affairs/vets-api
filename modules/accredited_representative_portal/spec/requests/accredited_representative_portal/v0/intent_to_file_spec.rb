# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::IntentToFileController, type: :request do
  let(:poa_code) { '067' }
  let(:poa_check_vcr_response) { '200_response' }
  let!(:test_user) do
    create(:representative_user, email: 'test@va.gov', icn: '123498767V234859', all_emails: ['test@va.gov'])
  end
  let!(:accredited_individual) do
    create(:user_account_accredited_individual,
           user_account_email: test_user.email,
           user_account_icn: test_user.icn,
           accredited_individual_registration_number: '357458',
           poa_code:)
  end
  let!(:vso) { create(:organization, poa: poa_code, can_accept_digital_poa_requests: true) }

  let!(:representative) do
    create(:representative,
           :vso,
           email: test_user.email,
           representative_id: accredited_individual.accredited_individual_registration_number,
           poa_codes: [poa_code])
  end
  let(:feature_flag_state) { true }

  before do
    allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('fake_access_token')
    login_as(test_user)
    allow(Flipper).to receive(:enabled?).with(
      :accredited_representative_portal_intent_to_file_api,
      instance_of(AccreditedRepresentativePortal::RepresentativeUser)
    ).and_return(feature_flag_state)
  end

  around do |example|
    VCR.use_cassette("lighthouse/benefits_claims/power_of_attorney/#{poa_check_vcr_response}") do
      example.run
    end
  end

  describe 'GET /accredited_representative_portal/v0/intent_to_file' do
    context 'feature flag is off' do
      let(:feature_flag_state) { false }

      it 'returns forbidden' do
        get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
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
      let(:poa_check_vcr_response) { '200_empty_response' }
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }

      it 'returns 403' do
        get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'ITF not found in Lighthouse' do
      it 'returns 404' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/404_response') do
          get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context 'rep has filed ITF' do
      it 'returns existing ITF filing for current user' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/200_response') do
          get('/accredited_representative_portal/v0/intent_to_file/123498767V234859?type=compensation')
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']['id']).to eq('193685')
        end
      end
    end
  end

  describe 'POST /accredited_representative_portal/v0/intent_to_file' do
    context 'feature flag is off' do
      let(:feature_flag_state) { false }

      it 'returns forbidden' do
        post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'happy path' do
      it 'submits an intent to file' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_200_response') do
          post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body).dig('data', 'id')).to eq '193685'
          expect(JSON.parse(response.body).dig('data', 'attributes', 'status')).to eq 'active'
        end
      end
    end

    context 'rep does not have POA for veteran' do
      let(:test_user) { create(:representative_user, email: 'notallowed@example.com') }
      let(:poa_check_vcr_response) { '200_empty_response' }

      it 'returns 403' do
        post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unprocessable entity' do
      it 'returns a 422' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_422_response') do
          post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'timeout from lighthouse submission' do
      it 'returns a 503' do
        VCR.use_cassette('lighthouse/benefits_claims/intent_to_file/create_compensation_503_response') do
          post('/accredited_representative_portal/v0/intent_to_file/?id=123498767V234859&type=compensation')
          expect(response).to have_http_status(:service_unavailable)
        end
      end
    end
  end
end
