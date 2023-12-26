# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/profile/v3/service'

describe VAProfile::Profile::V3::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3, edipi: '1100377582') }

  describe '#get_military_info' do
    include SchemaMatchers

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
end
