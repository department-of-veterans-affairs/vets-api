# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
def stub_vet360(person = nil)
  person ||= build(
    :person,
    addresses: [
      build(:vet360_address, id: 123),
      build(:vet360_address, address_pou: Vet360::Models::Address::CORRESPONDENCE, id: 124)
    ],
    emails: [
      build(:email, id: 456)
    ],
    telephones: [
      build(:telephone, :home, id: 789),
      build(:telephone, :home, phone_type: Vet360::Models::Telephone::MOBILE, id: 790),
      build(:telephone, :home, phone_type: Vet360::Models::Telephone::WORK, id: 791),
      build(:telephone, :home, phone_type: Vet360::Models::Telephone::FAX, id: 792),
      build(:telephone, :home, phone_type: Vet360::Models::Telephone::TEMPORARY, id: 793)
    ],
    permissions: [
      build(:permission, id: 1011),
      build(:permission, permission_type: Vet360::Models::Permission::TEXT, id: 1012)
    ]
  )

  allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_return(
    Vet360::ContactInformation::PersonResponse.new(200, person: person)
  )
end
# rubocop:enable Metrics/MethodLength
