# frozen_string_literal: true

require 'rails_helper'

describe VIC::IcnHelper do
  let(:fake_attributes) do
    {
      'veteran_full_name' => {
        'first' => 'first',
        'last' => 'last'
      },
      'veteran_date_of_birth' => '1950-01-01',
      'veteran_social_security_number' => '123456789',
      'gender' => 'M'
    }
  end

  describe '#create_mvi_profile' do
    it 'should create a mvi profile from attributes' do
      mvi_profile = described_class.create_mvi_profile(fake_attributes)
      expect(mvi_profile.given_names).to eq(['first'])
      expect(mvi_profile.family_name).to eq('last')
      expect(mvi_profile.birth_date).to eq('1950-01-01')
      expect(mvi_profile.ssn).to eq('123456789')
      expect(mvi_profile.gender).to eq('M')
    end
  end

  describe '#get_icns' do
    context 'with attributes that cant be found in mvi' do
      it 'should return false', run_at: 'Wed, 17 Jan 2018 03:49:00 GMT' do
        allow(SecureRandom).to receive(:uuid).and_return('cf2f7c67-6c12-464a-a6b7-3ee2ffe21298')

        VCR.use_cassette('mvi/find_candidate/find_profile_from_mvi_profile_invalid', VCR::MATCH_EVERYTHING) do
          expect(described_class.get_icns(fake_attributes)).to eq(false)
        end
      end
    end

    context 'with a valid request' do
      it 'should return icns', run_at: 'Fri, 12 Jan 2018 23:04:42 GMT' do
        allow(SecureRandom).to receive(:uuid).and_return('8c7e1f69-f9f1-4afb-bc67-a68e0c259a33')

        VCR.use_cassette('mvi/find_candidate/find_profile_from_mvi_profile', VCR::MATCH_EVERYTHING) do
          icns = described_class.get_icns(
            'veteran_full_name' => {
              'first' => 'Wesley',
              'middle' => 'Watson',
              'last' => 'Ford'
            },
            'veteran_date_of_birth' => '1986-05-06',
            'veteran_social_security_number' => '796043735',
            'gender' => 'M'
          )
          expect(icns).to eq(
            historical_icns: [],
            icn: '1012832025V743496'
          )
        end
      end
    end
  end
end
