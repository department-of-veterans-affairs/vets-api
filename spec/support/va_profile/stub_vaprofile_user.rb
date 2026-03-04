# frozen_string_literal: true

require 'va_profile/contact_information/v2/service'
require 'va_profile/contact_information/v2/person_response'
require 'va_profile/models/address'
require 'va_profile/models/telephone'

# rubocop:disable Metrics/MethodLength
def stub_vaprofile_user(person = nil)
  service = VAProfile::ContactInformation::V2::Service
  person_response = VAProfile::ContactInformation::V2::PersonResponse

  if person
    # Caller supplied a specific person — return it eagerly.
    allow_any_instance_of(service).to receive(:get_person).and_return(
      person_response.new(200, person:)
    )
  else
    # Lazily build the default person only when get_person is actually called.
    # This avoids constructing 8 factory objects for the ~93% of tests that
    # never exercise VA Profile contact information.
    allow_any_instance_of(service).to receive(:get_person) do
      person_response.new(200, person: FactoryBot.build(
        :person,
        addresses: [
          FactoryBot.build(:va_profile_address, id: 577_127),
          FactoryBot.build(:va_profile_address, address_pou: VAProfile::Models::Address::CORRESPONDENCE, id: 124)
        ],
        emails: [
          FactoryBot.build(:email, id: 318_927)
        ],
        telephones: [
          FactoryBot.build(:telephone, :home, id: 458_781),
          FactoryBot.build(:telephone, :mobile, phone_type: VAProfile::Models::Telephone::MOBILE, id: 790),
          FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::WORK, id: 791),
          FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::FAX, id: 792),
          FactoryBot.build(:telephone, :home, phone_type: VAProfile::Models::Telephone::TEMPORARY,
                                              id: 793)
        ]
      ))
    end
  end
end
# rubocop:enable Metrics/MethodLength
