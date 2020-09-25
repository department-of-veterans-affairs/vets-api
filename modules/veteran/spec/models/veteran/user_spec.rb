# frozen_string_literal: true

require 'rails_helper'

describe Veteran::User do
  context 'initialization' do
    let(:user) { FactoryBot.create(:user, :loa3) }

    before do
      external_key = user.common_name || user.email
      allow(BGS::Services).to receive(:new).with({ external_uid: user.icn, external_key: external_key })
    end

    it 'initializes from a user' do
      allow(Veteran::User).to receive(:new) { OpenStruct.new(power_of_attorney: PowerOfAttorney.new(code: 'A1Q')) }
      veteran = Veteran::User.new(user)
      expect(veteran.power_of_attorney.code).to eq('A1Q')
    end

    it 'does not bomb out if poa is missing' do
      allow(Veteran::User).to receive(:new) { OpenStruct.new(power_of_attorney: nil) }
      veteran = Veteran::User.new(user)
      expect(veteran.power_of_attorney).to eq(nil)
    end
  end
end
