# frozen_string_literal: true
require 'rails_helper'

describe VIC::VerifyVeteran do
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

  describe '#verify_veteran', run_at: 'Wed, 17 Jan 2018 03:49:00 GMT' do
    before do
      allow(SecureRandom).to receive(:uuid).and_return('cf2f7c67-6c12-464a-a6b7-3ee2ffe21298')
    end

    context 'with attributes that cant be found in mvi' do
      it 'should return false' do
        VCR.use_cassette('mvi/find_candidate/find_profile_from_mvi_profile_invalid', VCR::MATCH_EVERYTHING) do
          expect(described_class.send_request(fake_attributes)).to eq(false)
        end
      end
    end

    context 'when user cant be found in emis' do
      it 'should return false' do
        expect_any_instance_of(MVI::Service).to receive(:find_profile_from_mvi_profile).and_return(
          OpenStruct.new(
            profile: OpenStruct.new(
              emis_request_options: {
                edipi: '1111111111'
              }
            )
          )
        )

        VCR.use_cassette('emis/get_veteran_status/missing_edipi') do
          expect(described_class.send_request(fake_attributes)).to eq(false)
        end
      end
    end

    context 'with a valid request' do
      it 'should return veteran details' do
        VCR.use_cassette('vic/verify_veteran', VCR::MATCH_EVERYTHING) do
          response = described_class.send_request(
            'veteran_full_name' => {
              'first' => 'Wesley',
              'last' => 'Watson'
            },
            'veteran_date_of_birth' => '1986-05-06',
            'veteran_social_security_number' => '796043735',
            'gender' => 'M'
          )

          expect(response).to eq(
            veteran_address: {
              country: 'USA', street: '1723 MAIN RD', city: 'VIENNA', state: 'VA', postal_code: '22182'
            },
            phone: '(571)294-9259',
            service_branches: ['Air Force']
          )
        end
      end
    end
  end
end
