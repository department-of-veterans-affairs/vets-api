# frozen_string_literal: true

module Form1010cgHelpers
  def build_claim_data_for(form_subject, &mutations)
    data = {
      'fullName' => {
        'first' => Faker::Name.first_name,
        'last' => Faker::Name.last_name
      },
      'dateOfBirth' => Faker::Date.between(from: 100.years.ago, to: 18.years.ago).to_s,
      'address' => {
        'street' => Faker::Address.street_address,
        'city' => Faker::Address.city,
        'state' => Faker::Address.state_abbr,
        'postalCode' => Faker::Address.postcode
      },
      'primaryPhoneNumber' => Faker::Number.number(digits: 10).to_s
    }

    # Required properties for all caregivers
    data['vetRelationship'] = 'Daughter' if form_subject != :veteran

    # Required properties for :primaryCaregiver
    data['hasHealthInsurance'] = true if form_subject == :primaryCaregiver

    # Required property for :veteran
    if form_subject == :veteran
      data['ssnOrTin'] = Faker::IDNumber.valid.remove('-')
      data['plannedClinic'] = '568A4'
    end

    mutations&.call data, form_subject

    data
  end
end
