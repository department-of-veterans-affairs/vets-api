# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos community care eligibility', type: :request do
  include SchemaMatchers

  before do
    Flipper.enable('va_online_scheduling')
    sign_in_as(current_user)
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET eligibility' do
    let(:service_type) { 'PrimaryCare' }

    context 'loa1 user with flipper enabled' do
      let(:current_user) { build(:user, :loa1) }

      it 'does not have access' do
        get "/v0/vaos/community_care/eligibility/#{service_type}"
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
          get "/v0/vaos/community_care/eligibility/#{service_type}"
          expect(response).to have_http_status(:forbidden)
          expect(JSON.parse(response.body)['errors'].first['detail'])
            .to eq('You do not have access to online scheduling')
        end
      end

      it 'has access and returns eligibility true', :skip_mvi do
        VCR.use_cassette('vaos/cc_eligibility/get_eligibility_true', match_requests_on: %i[method uri]) do
          get "/v0/vaos/community_care/eligibility/#{service_type}"

          expect(response).to have_http_status(:success)
          expect(response.body).to be_a(String)
          expect(json_body_for(response)).to match_schema('vaos/cc_eligibility')
        end
      end

      context 'with access and invalid service_type' do
        let(:service_type) { 'NotAType' }

        it 'returns a validation error', :skip_mvi do
          VCR.use_cassette('vaos/cc_eligibility/get_eligibility_400', match_requests_on: %i[method uri]) do
            get "/v0/vaos/community_care/eligibility/#{service_type}"

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
