# frozen_string_literal: true

def stub_vet360(person = nil)
  person ||= build(:person,
                   addresses:  [build(:vet360_address, id: 123)],
                   emails:     [build(:email, id: 456)],
                   telephones: [build(:telephone, :home, id: 789)])

  allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_return(
    Vet360::ContactInformation::PersonResponse.new(200, person: person)
  )
end
