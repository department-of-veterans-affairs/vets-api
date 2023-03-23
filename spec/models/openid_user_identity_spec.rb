# frozen_string_literal: true

require 'rails_helper'
require 'okta/service'

RSpec.describe OpenidUserIdentity, type: :model do
  let(:some_ttl) { 86_400 }
  let(:loa_three) { { current: LOA::THREE, highest: LOA::THREE } }
  let(:okta_service) { Okta::Service.new }

  describe '.build_from_profile' do
    it 'is compatible with the okta profile' do
      with_okta_profile_configured do
        okta_response = okta_service.user('00u1zlqhuo3yLa2Xs2p7')
        profile = Okta::UserProfile.new(okta_response.body['profile'])
        identity = OpenidUserIdentity.build_from_profile(uuid: 'abc123', profile:, ttl: some_ttl)
        expect(identity.uuid).to eq('abc123')
        expect(identity.first_name).to eq('KELLY')
        expect(identity.last_name).to eq('CARROLL')
        expect(identity.middle_name).to eq('D')
        expect(identity.gender).to be_nil
        expect(identity.loa).to eq(loa_three)
      end
    end

    it 'is compatible with the okta profile that includes uuid (ssoe)' do
      with_okta_profile_with_uuid_configured do
        okta_response = okta_service.user('00u1zlqhuo3yLa2Xs2p7')
        profile = Okta::UserProfile.new(okta_response.body['profile'])
        identity = OpenidUserIdentity.build_from_profile(uuid: 'abc123', profile:, ttl: some_ttl)
        expect(identity.uuid).to eq('abc123')
        expect(identity.first_name).to eq('KELLY')
        expect(identity.last_name).to eq('CARROLL')
        expect(identity.middle_name).to eq('D')
        expect(identity.gender).to be_nil
        expect(identity.loa).to eq(loa_three)
      end
    end

    it 'is compatible with the okta profile that includes ial/aal (login.gov)' do
      with_okta_profile_with_ial_aal_configured do
        okta_response = okta_service.user('00u1zlqhuo3yLa2Xs2p7')
        profile = Okta::UserProfile.new(okta_response.body['profile'])
        identity = OpenidUserIdentity.build_from_profile(uuid: 'abc123', profile:, ttl: some_ttl)
        expect(identity.uuid).to eq('abc123')
        expect(identity.first_name).to eq('KELLY')
        expect(identity.last_name).to eq('CARROLL')
        expect(identity.gender).to be_nil
        expect(identity.loa).to eq(loa_three)
      end
    end
  end
end
