# frozen_string_literal: true

def stub_vet360(person = nil)
  allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:safe_get_person).and_return(
    Vet360::ContactInformation::PersonResponse.new(
      200,
      person: person || build(:person)
    )
  )
end
