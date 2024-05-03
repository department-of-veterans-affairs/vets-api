# frozen_string_literal: true

require_relative '../../support/helpers/rails_helper'
require 'common/client/errors'

RSpec.describe 'user', type: :request do
  include JsonSchemaMatchers

  describe 'GET /mobile/v2/user' do
    let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef') }
    let(:get_user) { get '/mobile/v2/user', headers: sis_headers }
    let(:attributes) { response.parsed_body.dig('data', 'attributes') }

    before { Flipper.enable_actor(:mobile_v1_lighthouse_facilities, user) }

    after { Flipper.disable(:mobile_v1_lighthouse_facilities) }

    it 'returns an ok response' do
      get_user
      expect(response).to have_http_status(:ok)
    end

    it 'returns a user profile response with the expected schema' do
      get_user
      expect(response.body).to match_json_schema('v2/user')
    end

    it 'includes the users names' do
      get_user
      expect(attributes['firstName']).to eq(user.first_name)
      expect(attributes['middleName']).to eq(user.middle_name)
      expect(attributes['lastName']).to eq(user.last_name)
    end

    it 'eqs the users sign-in email' do
      get_user
      expect(attributes['signinEmail']).to eq(user.email)
    end

    it 'includes the user\'s birth_date' do
      get_user
      expect(attributes['birthDate']).to eq(Date.parse(user.birth_date).iso8601)
    end

    it 'includes sign-in service' do
      get_user
      expect(attributes['signinService']).to eq('idme')
    end

    describe 'has_facility_transitioning_to_cerner' do
      context 'with feature flag off and user\'s va_treatment_facility_ids contains the hardcoded facility id' do
        let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', vha_facility_ids: ['979']) }

        before { Flipper.disable(:mobile_cerner_transition) }
        after { Flipper.enable(:mobile_cerner_transition) }

        it 'sets hasFacilityTransitioningToCerner to false' do
          get_user
          expect(attributes['hasFacilityTransitioningToCerner']).to eq(false)
        end
      end

      context 'with feature flag on and user\'s va_treatment_facility_ids contains the hardcoded facility id' do
        let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', vha_facility_ids: ['979']) }

        before { Flipper.enable(:mobile_cerner_transition) }

        it 'sets hasFacilityTransitioningToCerner to true' do
          get_user
          expect(attributes['hasFacilityTransitioningToCerner']).to eq(true)
        end
      end

      context "with feature flag on and user's va_treatment_facility_ids does not contain the hardcoded facility id" do
        let!(:user) { sis_user(idme_uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef', vha_facility_ids: ['555']) }

        before { Flipper.enable(:mobile_cerner_transition) }

        it 'sets hasFacilityTransitioningToCerner to false' do
          get_user
          expect(attributes['hasFacilityTransitioningToCerner']).to eq(false)
        end
      end
    end
  end
end
