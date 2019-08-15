# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::Veteran, type: :model do
  let(:headers) do
    {
      'X-VA-SSN' => '123456789',
      'X-VA-First-Name' => 'MARK',
      'X-VA-Last-Name' => 'WEBB',
      'X-VA-Birth-Date' => '1928-01-01'
    }
  end
  describe 'attributes needed for MVI lookup' do
    before do
      @veteran = ClaimsApi::Veteran.new
      @veteran.loa = { current: 3, highest: 3 }
      @veteran.edipi = '1234567'
    end

    it 'should delagate loa_user to loa3?' do
      expect(@veteran.loa3_user).to be(true)
    end

    it 'should always be valid for now to meet MVI need' do
      expect(@veteran.valid?).to be(true)
    end

    it 'should set edipi if passed in headers' do
      veteran = ClaimsApi::Veteran.from_headers(headers.merge!('X-VA-EDIPI' => 1337))
      expect(veteran.edipi).to eq('1337')
    end
  end

  describe 'setting edipi from mvi' do
    let(:mvi_profile) { build(:mvi_profile, edipi: 1337) }

    before do
      @veteran = ClaimsApi::Veteran.new
      @veteran.loa = { current: 3, highest: 3 }
    end

    it 'should set edipi from mvi when not passed in headers' do
      allow_any_instance_of(Mvi).to receive(:profile).and_return(mvi_profile)
      veteran = ClaimsApi::Veteran.from_headers(headers)
      expect(veteran.edipi).to eq('1337')
    end
  end

  describe 'setting target veteran by oauth' do
    it 'should instantiate from the oauth user' do
      identity = FactoryBot.create(:openid_user, identity_attrs: build(:user_identity_attrs, :loa3))
      veteran = ClaimsApi::Veteran.from_identity(identity: identity)
      expect(veteran.first_name).to eq(identity.first_name)
    end
  end
end
