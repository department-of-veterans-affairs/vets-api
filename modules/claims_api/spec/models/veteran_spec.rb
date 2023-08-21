# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Veteran, type: :model do
  before do
    @veteran = ClaimsApi::Veteran.new
    @veteran.va_profile = ClaimsApi::Veteran.build_profile('1990-01-01')
    @veteran.loa = { current: 3, highest: 3 }
    @veteran.edipi = '1234567'
  end

  describe 'attributes needed for MPI lookup' do
    it 'delegates loa_user to loa3?' do
      expect(@veteran.loa3_user).to be(true)
    end

    it 'is valid when proper MPI values exist' do
      expect(@veteran.valid?).to be(true)
    end
  end

  describe 'setting target veteran by OAuth' do
    it 'instantiates from the OAuth user' do
      identity = FactoryBot.create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3))
      veteran = ClaimsApi::Veteran.from_identity(identity:)
      expect(veteran.first_name).to eq(identity.first_name)
    end
  end

  describe 'handles errors' do
    it 'raises on invalid SSN' do
      @veteran.ssn = nil
    rescue => e
      expect(e.errors[0].detail).to be(
        'Invalid SSN in Master Person Index (MPI). ' \
        'Please submit an issue at ask.va.gov or call ' \
        '1-800-MyVA411 (800-698-2411) for assistance.'
      )
    end
  end
end
