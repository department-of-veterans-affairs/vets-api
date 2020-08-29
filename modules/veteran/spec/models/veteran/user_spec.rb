# frozen_string_literal: true

require 'rails_helper'

describe Veteran::User do
  context 'initialization' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    before do
      @client_stub = instance_double('BGS::Services')
      allow(BGS::Services).to receive(:new).with({ external_uid: '', external_key: '' })
    end

    it 'initializes from a user' do
      allow(@client_stub).to receive(:claimant).and_return(nil)
      allow(@client_stub.claimant).to receive(:find_poa_by_participant_id) { get_fixture('json/bgs_with_poa') }
      veteran = Veteran::User.new(user)
      expect(veteran.power_of_attorney.code).to eq('A1Q')
    end

    it 'does not bomb out if poa is missing' do
      allow(@client_stub).to receive(:claimant).and_return(nil)
      allow(@client_stub.claimant).to receive(:find_poa_by_participant_id) { get_fixture('json/bgs_without_poa') }
      veteran = Veteran::User.new(user)
      expect(veteran.power_of_attorney).to eq(nil)
    end
  end
end
