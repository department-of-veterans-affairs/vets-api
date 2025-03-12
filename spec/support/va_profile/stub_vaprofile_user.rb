# frozen_string_literal: true

require 'va_profile/v2/contact_information/service'
require 'va_profile/v2/contact_information/person_response'
require 'va_profile/models/v3/address'
require 'va_profile/models/telephone'

# rubocop:disable Metrics/MethodLength
def stub_vaprofile_user(person = nil)
  service = VAProfile::V2::ContactInformation::Service
  person_response = VAProfile::V2::ContactInformation::PersonResponse
  person ||= build(
    :person_v2,
    addresses: [
      build(:va_profile_v3_address, id: 577_127),
      build(:va_profile_v3_address, address_pou: VAProfile::Models::V3::Address::CORRESPONDENCE, id: 124)
    ],
    emails: [
      build(:email, :contact_info_v2, id: 318_927)
    ],
    telephones: [
      build(:telephone, :contact_info_v2, :home, id: 458_781),
      build(:telephone, :contact_info_v2_mobile, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
      build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
      build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
      build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY, id: 793)
    ]
  )

  allow_any_instance_of(service).to receive(:get_person).and_return(
    person_response.new(200, person:)
  )
end
# rubocop:enable Metrics/MethodLength
