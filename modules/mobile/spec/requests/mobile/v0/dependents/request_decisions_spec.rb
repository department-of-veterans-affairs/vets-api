# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Dependents::RequestDecisions', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  describe 'GET /dependents/request-decisions' do
    let!(:user) { sis_user }
    let(:attributes) { response.parsed_body.dig('data', 'attributes') }

    it 'returns expected response' do
      VCR.use_cassette('bgs/diaries_service/read_diaries', match_requests_on: %i[method uri]) do
        allow(user).to receive(:participant_id).and_return('13014883')
        get('/mobile/v0/dependents/request-decisions', headers: sis_headers)
      end
      assert_schema_conform(200)
      expect(attributes['promptRenewal']).to be(true)
    end

    context 'when no diaries exist' do
      it 'returns an empty diaries array' do
        VCR.use_cassette('bgs/diaries_service/read_empty_diaries') do
          allow(user).to receive(:participant_id).and_return('123')
          get('/mobile/v0/dependents/request-decisions', headers: sis_headers)
        end
        assert_schema_conform(200)
        expect(attributes['diaries']).to eq([])
        expect(attributes['promptRenewal']).to be(false)
      end
    end

    context 'when one diary exists that does not meet criteria for renewal' do
      it 'sets promptRenewal to false' do
        VCR.use_cassette('bgs/diaries_service/read_diaries_one_entry_cxcl') do
          allow(user).to receive(:participant_id).and_return('13014883')
          get('/mobile/v0/dependents/request-decisions', headers: sis_headers)
        end
        assert_schema_conform(200)
        expect(attributes['diaries'].count).to eq(1)
        expect(attributes.dig('diaries', 0, 'diaryLcStatusType')).to eq('CXCL')
        expect(attributes['promptRenewal']).to be(false)
      end
    end

    context 'when one dependency verification exists' do
      it 'returns one dependency verification' do
        VCR.use_cassette('bgs/diaries_service/read_diaries_one_entry') do
          allow(user).to receive(:participant_id).and_return('13014883')
          get('/mobile/v0/dependents/request-decisions', headers: sis_headers)
        end
        assert_schema_conform(200)
        expect(attributes['dependencyVerifications'].count).to eq(1)
        expect(attributes['promptRenewal']).to be(true)
      end
    end
  end
end
