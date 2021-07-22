# frozen_string_literal: true

require 'okta/user_profile.rb'

RSpec.describe Okta::UserProfile do
  describe '#initialize' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'myhealthevet',
        'mhv_account_type': 'Premium'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'creates the okta service correctly' do
      expect(user_profile).to be_instance_of(Okta::UserProfile)
    end
  end

  describe '#confirm loa mappings saml proxy mhv premium' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'myhealthevet',
        'mhv_account_type': 'Premium'
      }
    end
    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives saml proxy mhv premium loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(3)
      expect(response[:highest]).to eq(3)
    end
  end

  describe '#confirm loa mappings saml proxy mhv basic' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'myhealthevet',
        'mhv_account_type': 'Basic'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives saml proxy mhv basic loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(1)
      expect(response[:highest]).to eq(1)
    end
  end

  describe '#confirm loa mappings saml proxy dslogon premium' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'dslogon',
        'dslogon_assurance': '3'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives saml proxy dslogon premium loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(3)
      expect(response[:highest]).to eq(3)
    end
  end

  describe '#confirm loa mappings saml proxy dslogon basic' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'dslogon',
        'dslogon_assurance': '1'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives saml proxy dslogon basic loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(1)
      expect(response[:highest]).to eq(1)
    end
  end

  describe '#confirm loa mappings saml proxy idme' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'idme',
        'idme_loa': '3'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives saml proxy idme loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(3)
      expect(response[:highest]).to eq(3)
    end
  end

  describe '#confirm loa mappings ssoe idme' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': '200VIDM',
        'loa': '3'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives ssoe idme loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(3)
      expect(response[:highest]).to eq(3)
    end
  end

  describe '#confirm loa mappings last_login_type based' do
    let(:user_profile_json) do
      {
        'email': 'john.doe@va.gov',
        'firstName': 'John',
        'lastName': 'Doe',
        'icn': '12345V67890',
        'last_login_type': 'ssoe-saml'
      }
    end

    let(:user_profile_struct) { OpenStruct.new(user_profile_json) }
    let(:user_profile) { described_class.new(user_profile_struct) }

    it 'derives last_login_type based loa' do
      response = user_profile.derived_loa
      expect(response[:current]).to eq(3)
      expect(response[:highest]).to eq(3)
    end
  end
end
