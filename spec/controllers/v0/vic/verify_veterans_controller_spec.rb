# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::VIC::VerifyVeteransController, type: :controller do
  describe '#create' do
    it 'it returns verified for a valid veteran', run_at: 'Wed, 17 Jan 2018 03:49:00 GMT' do
      allow(SecureRandom).to receive(:uuid).and_return('cf2f7c67-6c12-464a-a6b7-3ee2ffe21298')

      VCR.use_cassette('vic/verify_veteran', VCR::MATCH_EVERYTHING) do
        post(:create, veteran: {
          'veteran_full_name' => {
            'first' => 'Wesley',
            'last' => 'Watson'
          },
          'veteran_date_of_birth' => '1986-05-06',
          'veteran_social_security_number' => '796043735',
          'gender' => 'M'
        })

        expect(JSON.parse(response.body)).to eq('verified' => true)
      end
    end
  end
end
