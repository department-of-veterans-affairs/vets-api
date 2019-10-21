# frozen_string_literal: true

require 'rails_helper'

describe MVI::AttrService do
  describe '#find_profile' do
    it 'allows searching mvi with user attributes', run_at: 'Thu, 29 Aug 2019 17:45:03 GMT' do
      allow(SecureRandom).to receive(:uuid).and_return('c3fa0769-70cb-419a-b3a6-d2563e7b8502')

      VCR.use_cassette(
        'mvi/find_candidate/find_profile_with_attributes',
        VCR::MATCH_EVERYTHING
      ) do
        res = described_class.new.find_profile(
          HCA::UserAttributes.new(
            first_name: 'WESLEY',
            last_name: 'FORD',
            birth_date: '1986-05-06',
            ssn: '796043735'
          )
        )
        expect(res.profile.icn).to eq('1012832025V743496')
      end
    end
  end
end
