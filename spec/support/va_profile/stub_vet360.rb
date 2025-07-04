# frozen_string_literal: true

require 'va_profile/contact_information/service'
require 'va_profile/contact_information/person_response'
require 'va_profile/models/address'
require 'va_profile/models/telephone'
require 'va_profile/models/permission'

# rubocop:disable Metrics/MethodLength
def stub_vet360(person = nil)
  Flipper.disable(:remove_pciu)
  service = VAProfile::ContactInformation::Service
  person_response = VAProfile::ContactInformation::PersonResponse

  person ||= FactoryBot.build(
    :person,
    addresses: [
      FactoryBot.build(:va_profile_address, id: 123),
      FactoryBot.build(:va_profile_address, address_pou: VAProfile::Models::Address::CORRESPONDENCE, id: 124)
    ],
    emails: [
      FactoryBot.build(:email, id: 456)
    ],
    telephones: [
      FactoryBot.build(:telephone, :home, id: 789),
      FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
      FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
      FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
      FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY, id: 793)
    ],
    permissions: [
      FactoryBot.build(:permission, id: 1011),
      FactoryBot.build(:permission, permission_type: VAProfile::Models::Permission::TEXT, id: 1012)
    ]
  )

  allow_any_instance_of(service).to receive(:get_person).and_return(
    person_response.new(200, person:)
  )
end
# rubocop:enable Metrics/MethodLength
