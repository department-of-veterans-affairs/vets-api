require 'rails_helper'

describe VIC::VerifyVeteran do
  describe '#create_mvi_profile' do
    it 'should create a mvi profile from attributes' do
      mvi_profile = described_class.create_mvi_profile(
        'veteran_full_name' => {
          'first' => 'first',
          'last' => 'last'
        },
        'veteran_date_of_birth' => '1950-01-01',
        'veteran_social_security_number' => '123456789',
        'gender' => 'M'
      )
      expect(mvi_profile.given_names).to eq(['first'])
      expect(mvi_profile.family_name).to eq('last')
      expect(mvi_profile.birth_date).to eq('1950-01-01')
      expect(mvi_profile.ssn).to eq('123456789')
      expect(mvi_profile.gender).to eq('M')
    end
  end
end
