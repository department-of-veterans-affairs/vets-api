# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Veteran, type: :model do
  describe 'attributes needed for MVI lookup' do
    before do
      @veteran = ClaimsApi::Veteran.new
      @veteran.va_profile = ClaimsApi::Veteran.build_profile('1990-01-01')
      @veteran.loa = { current: 3, highest: 3 }
      @veteran.edipi = '1234567'
    end

    it 'delagates loa_user to loa3?' do
      expect(@veteran.loa3_user).to be(true)
    end

    it 'onlies be valid when proper MVI values are exist' do
      expect(@veteran.valid?).to be(true)
    end
  end

  describe 'setting target veteran by oauth' do
    it 'instantiates from the oauth user' do
      identity = FactoryBot.create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3))
      veteran = ClaimsApi::Veteran.from_identity(identity: identity)
      expect(veteran.first_name).to eq(identity.first_name)
    end
  end
end
