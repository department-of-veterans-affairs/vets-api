# frozen_string_literal: true

require 'va_profile/v2/contact_information/service'
require 'va_profile/v2/contact_information/person_response'
require 'va_profile/models/v3/address'
require 'va_profile/models/telephone'
require 'va_profile/models/email'

def stub_va_profile_user(person)
  person_response =
  person_response = VCR.use_cassette('va_profile/v2/contact_information/person') do
    VAProfile::V2::ContactInformation::Service.new(person).get_person
  end
  # person ||= build(
  #   :person_v2,
  #   addresses: [
  #     build(:va_profile_v3_address, id: 577_127),
  #     build(:va_profile_v3_address, address_pou: VAProfile::Models::V3::Address::CORRESPONDENCE, id: 124)
  #   ],
  #   emails: [
  #     build(:email, :contact_info_v2, id: 318_927)
  #   ],
  #   telephones: [
  #     build(:telephone, :contact_info_v2, :home, id: 458_781),
  #     build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
  #     build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
  #     build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
  #     build(:telephone, :contact_info_v2, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY, id: 793)
  #   ]
  # )

  allow_any_instance_of(VAProfile::V2::ContactInformation::Service).to receive(:get_person).and_return(person_response)

  [person_response]
end
