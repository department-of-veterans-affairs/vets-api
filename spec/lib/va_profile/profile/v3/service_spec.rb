# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/service'

describe VAProfile::Profile::V3::Service do
  include SchemaMatchers

  subject { described_class.new(user) }

  describe '#get_military_info' do
    let(:user) { build(:user, :loa3, edipi: '1100377582') }

    context 'when successful' do
      it 'returns a valid schema' do
        VCR.use_cassette('va_profile/profile/v3/military_info_200') do
          response = subject.get_military_info

          expect(response.status).to eq(200)
          expect(response).to match_response_schema('va_profile/profile/v3/military_info_response')
        end
      end
    end
  end

  describe '#get_health_benefit_bio' do
    let(:idme_uuid) { 'e444837a-e88b-4f59-87da-10d3c74c787b' }
    let(:user) { build(:user, :loa3, idme_uuid:) }

    it 'returns a valid schema' do
      VCR.use_cassette('va_profile/profile/v3/health_benefit_bio_200') do
        response = subject.get_health_benefit_bio

        expect(response.status).to eq(200)
      end
    end
  end
end
