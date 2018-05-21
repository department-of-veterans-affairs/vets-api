# frozen_string_literal: true

def stub_vet360(person = nil)
  person_resp = Vet360::ContactInformation::PersonResponse.new(200, OpenStruct.new(body: { 'bio' => {} }))
  person_resp.person = person || build(:person)
  allow_any_instance_of(Vet360::ContactInformation::Service).to receive(:get_person).and_return(
    person_resp
  )
end
