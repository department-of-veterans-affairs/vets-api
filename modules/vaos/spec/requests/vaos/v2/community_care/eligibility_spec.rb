# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'VAOS::V2::CommunityCare::Eligibility', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling') # rubocop:disable Project/ForbidFlipperToggleInSpecs
    allow(Flipper).to receive(:enabled?).with(:va_online_scheduling_vaos_alternate_route).and_return(false)
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET eligibility' do
    let(:service_type) { 'PrimaryCare' }

    context 'loa1 user with flipper enabled' do
      let(:current_user) { build(:user, :loa1) }

      it 'does not have access' do
        get "/vaos/v2/community_care/eligibility/#{service_type}"
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('You do not have access to online scheduling')
      end
    end

    context 'loa3 user' do
      let(:current_user) { build(:user, :vaos) }

      it 'has access and returns eligibility true', :skip_mvi do
        VCR.use_cassette('vaos/cc_eligibility/get_eligibility_true', match_requests_on: %i[method path query]) do
          logged_info =
            { icn_digest: '434fce82be04d498f7e7e54f30c0d4c35f61bc4e53610137bcb446723597732a',
              service_type: 'PrimaryCare',
              eligible: true,
              eligibility_codes: [{ description: 'Hardship', code: 'H' }],
              no_full_service_va_medical_facility: false,
              grandfathered: false,
              timestamp: '2019-12-13T09:19:05.253378Z' }.to_json

          allow(Rails.logger).to receive(:info).at_least(:once)

          get "/vaos/v2/community_care/eligibility/#{service_type}"
          expect(Rails.logger).to have_received(:info).with('VAOS CCEligibility details', logged_info).at_least(:once)
          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(json_body_for(response)).to match_schema('vaos/cc_eligibility')
        end
      end

      context 'with access and invalid service_type' do
        let(:service_type) { 'NotAType' }

        it 'returns a validation error', :skip_mvi do
          VCR.use_cassette('vaos/cc_eligibility/get_eligibility_400', match_requests_on: %i[method path query]) do
            get "/vaos/v2/community_care/eligibility/#{service_type}"

            expect(response).to have_http_status(:bad_request)
            expect(response.body).to be_a(String)
            expect(JSON.parse(response.body)['errors'].first['detail'])
              .to eq('Unknown service type: NotAType')
          end
        end
      end
    end
  end
end
