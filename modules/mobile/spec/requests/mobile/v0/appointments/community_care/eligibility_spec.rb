# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'
require_relative '../../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appointments::CommunityCare::Eligibility', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '9000682') }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

  before do
    allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token')
  end

  describe 'GET /mobile/v0/community_care/eligibility/:service_type' do
    context 'valid service type' do
      context 'eligible service type' do
        let(:service_type) { 'primaryCare' }

        before do
          allow(Rails.logger).to receive(:info)
          VCR.use_cassette('mobile/cc_eligibility/get_eligibility_true', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/community_care/eligibility/#{service_type}", headers: sis_headers
          end
        end

        it 'returns successful response' do
          assert_schema_conform(200)
        end

        it 'returns true eligibility' do
          eligibility = response.parsed_body.dig('data', 'attributes', 'eligible')
          expect(eligibility).to be(true)
        end

        it 'returns expected schema' do
          expect(response.body).to match_json_schema('cc_eligibility')
        end
      end

      context 'non-eligible service type' do
        let(:service_type) { 'optometry' }

        before do
          VCR.use_cassette('mobile/cc_eligibility/get_eligibility_false', match_requests_on: %i[method uri]) do
            get "/mobile/v0/appointments/community_care/eligibility/#{service_type}", headers: sis_headers
          end
        end

        it 'returns successful response' do
          assert_schema_conform(200)
        end

        it 'returns false eligibility' do
          eligibility = response.parsed_body.dig('data', 'attributes', 'eligible')
          expect(eligibility).to be(false)
        end
      end
    end

    context 'invalid service type' do
      let(:service_type) { 'NotAType' }

      before do
        VCR.use_cassette('mobile/cc_eligibility/get_eligibility_400', match_requests_on: %i[method uri]) do
          get "/mobile/v0/appointments/community_care/eligibility/#{service_type}", headers: sis_headers
        end
      end

      it 'returns bad request response' do
        assert_schema_conform(400)
      end

      it 'returns unknown service type error' do
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq("Unknown service type: #{service_type}")
      end
    end
  end
end
