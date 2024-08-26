# frozen_string_literal: true

require 'va_profile/contact_information/service'
require 'va_profile/v2/contact_information/service'
require 'va_profile/contact_information/person_response'
require 'va_profile/v2/contact_information/person_response'
require 'va_profile/models/address'
require 'va_profile/models/telephone'
require 'va_profile/models/permission'

# rubocop:disable Metrics/MethodLength
def stub_vet360(person = nil)
  service = if Flipper.enabled?(:va_v3_contact_information_service)
              VAProfile::V2::ContactInformation::Service
            else
              VAProfile::ContactInformation::Service
            end

  person_response = if Flipper.enabled?(:va_v3_contact_information_service)
                      VAProfile::V2::ContactInformation::PersonResponse
                    else
                      VAProfile::ContactInformation::PersonResponse
                    end

  person ||= build(
    :person,
    addresses: [
      build(:va_profile_address, id: 123),
      build(:va_profile_address, address_pou: VAProfile::Models::Address::CORRESPONDENCE, id: 124)
    ],
    emails: [
      build(:email, id: 456)
    ],
    telephones: [
      build(:telephone, :home, id: 789),
      build(:telephone, :home, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
      build(:telephone, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
      build(:telephone, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
      build(:telephone, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY, id: 793)
    ],
    permissions: [
      build(:permission, id: 1011),
      build(:permission, permission_type: VAProfile::Models::Permission::TEXT, id: 1012)
    ]
  )

  allow_any_instance_of(service).to receive(:get_person).and_return(
    person_response.new(200, person:)
  )
end
# rubocop:enable Metrics/MethodLength
