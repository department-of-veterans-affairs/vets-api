# frozen_string_literal: true

require 'va_profile/contact_information/v2/service'
require 'va_profile/contact_information/v2/person_response'
require 'va_profile/models/address'
require 'va_profile/models/telephone'

# rubocop:disable Metrics/MethodLength
def stub_vaprofile_user(person = nil)
  service = VAProfile::ContactInformation::V2::Service
  person_response = VAProfile::ContactInformation::V2::PersonResponse
  person ||= FactoryBot.build(
    :person,
    addresses: [
      FactoryBot.build(:va_profile_address, id: 577_127),
      FactoryBot.build(:va_profile_address, address_pou: VAProfile::Models::Address::CORRESPONDENCE, id: 124)
    ],
    emails: [
      FactoryBot.build(:email, :contact_info_v2, id: 318_927)
    ],
    telephones: [
      FactoryBot.build(:telephone, :contact_info_v2, :home, id: 458_781),
      FactoryBot.build(:telephone, :contact_info_v2_mobile, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
      FactoryBot.build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
      FactoryBot.build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
      FactoryBot.build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY,
                                                            id: 793)
    ]
  )

  allow_any_instance_of(service).to receive(:get_person).and_return(
    person_response.new(200, person:)
  )
end
# rubocop:enable Metrics/MethodLength
