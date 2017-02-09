# frozen_string_literal: true
FactoryGirl.define do
  factory :form_profile do
    user_uuid '5090027a-b9f2-44c4-acd7-45f2640d5e83'
    applicant_information do
      {
        fullName: {
          first: 'Abraham',
          middle: 'Vampire Hunter',
          last: 'Lincoln',
          suffix: 'III'
        }
      }.to_json
    end
    contact_information do
      {
        address: {
          street: '140 Rock Creek Church Road NW',
          street2: nil,
          city: 'Washington',
          state: 'DC',
          postalCode: '20011',
          country: 'USA'
        },
        homePhone: nil,
        mobilePhone: '1112223344'
      }.to_json
    end
  end
end
