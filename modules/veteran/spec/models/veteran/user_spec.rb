# frozen_string_literal: true

require 'rails_helper'

describe Veteran::User do
  context 'initialization' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    it 'initializes from a user' do
      VCR.use_cassette('bgs/claimant_web_service/find_poa_by_participant_id') do
        allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({ person_poa_history: { person_poa: [{ begin_date: Time.zone.now, legacy_poa_cd: '033' }] } })
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney.code).to eq('044')
        expect(veteran.previous_power_of_attorney.code).to eq('033')
      end
    end

    it 'does not bomb out if poa is missing' do
      VCR.use_cassette('bgs/claimant_web_service/not_find_poa_by_participant_id') do
        allow_any_instance_of(BGS::OrgWebService).to receive(:find_poa_history_by_ptcpnt_id)
          .and_return({ person_poa_history: nil })
        veteran = Veteran::User.new(user)
        expect(veteran.power_of_attorney).to eq(nil)
        expect(veteran.previous_power_of_attorney).to eq(nil)
      end
    end
  end
end
