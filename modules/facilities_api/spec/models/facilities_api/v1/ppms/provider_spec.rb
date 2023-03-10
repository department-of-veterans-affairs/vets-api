# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FacilitiesApi::V1::PPMS::Provider, type: :model, team: :facilities do
  shared_examples 'transforms param into attribute' do |param, attribute, value|
    it "transforms #{param} into #{attribute}" do
      provider = FacilitiesApi::V1::PPMS::Provider.new(param => value)
      expect(provider.attributes[attribute]).to eql(value)
    end
  end

  context 'Creating' do
    it 'defaults to false' do
      provider = FacilitiesApi::V1::PPMS::Provider.new
      expect(provider.attributes).to match(
        {
          acc_new_patients: nil,
          address_city: nil,
          address_postal_code: nil,
          address_state_province: nil,
          address_street: nil,
          care_site: nil,
          caresite_phone: nil,
          contact_method: nil,
          email: nil,
          fax: nil,
          gender: nil,
          id: nil,
          latitude: nil,
          longitude: nil,
          main_phone: nil,
          miles: nil,
          name: nil,
          pos_codes: nil,
          provider_identifier: nil,
          provider_name: nil,
          provider_type: 'GroupPracticeOrAgency'
        }
      )
    end

    include_examples 'transforms param into attribute', :is_accepting_new_patients, :acc_new_patients, 'true'
    include_examples 'transforms param into attribute', :provider_accepting_new_patients, :acc_new_patients, 'true'

    include_examples 'transforms param into attribute', :care_site_address_city, :address_city, 'SomeCity'
    include_examples 'transforms param into attribute', :care_site_address_zip_code, :address_postal_code, 'SomeZip'
    include_examples 'transforms param into attribute', :care_site_address_state, :address_state_province, 'SomeState'
    include_examples 'transforms param into attribute', :care_site_address_street, :address_street, 'SomeStreet'

    include_examples 'transforms param into attribute', :care_site_phone_number, :caresite_phone, 'SomePhone'
    include_examples 'transforms param into attribute', :contact_method, :contact_method, 'Fax'

    include_examples 'transforms param into attribute', :organization_fax, :fax, 'SomeFax'

    include_examples 'transforms param into attribute', :provider_gender, :gender, 'SomeGender'

    include_examples 'transforms param into attribute', :provider_identifier, :id, 'SomeID'

    it 'sets a hexdigest as the id' do
      provider = FacilitiesApi::V1::PPMS::Provider.new
      provider.set_hexdigest_as_id!
      expect(provider.id).to eql('21f31fd330909ba9f74eb7fea7d1c6c7605008529f513f844fd35d7ba91d4786')
    end

    it 'sets the provider_type to GroupPracticeOrAgency' do
      provider = FacilitiesApi::V1::PPMS::Provider.new(provider_type: 'SomeType')
      expect(provider.provider_type).to eql('SomeType')
      provider.set_group_practice_or_agency!
      expect(provider.provider_type).to eql('GroupPracticeOrAgency')
    end
  end
end
