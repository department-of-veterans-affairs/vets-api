# frozen_string_literal: true

require 'rails_helper'

describe Veteran::User do
  context 'initialization' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    it 'initializes from a user' do
      VCR.use_cassette('bgs/claimant_web_service/find_poa_by_participant_id') do
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney.code).to eq('044')
      end
    end

    it 'does not bomb out if poa is missing' do
      VCR.use_cassette('bgs/claimant_web_service/not_find_poa_by_participant_id') do
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney).to eq(nil)
      end
    end
  end
end
