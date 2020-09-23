# frozen_string_literal: true

module SavedClaimHelper
  class Form1010cgHelper
    # rubocop:disable Metrics/MethodLength
    def self.build_claim_data_for(form_subject, &mutations)
      data = {
        'fullName' => {
          'first' => Faker::Name.first_name,
          'last' => Faker::Name.last_name
        },
        'ssnOrTin' => Faker::IDNumber.valid.remove('-'),
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
      if form_subject == :primaryCaregiver
        data['medicaidEnrolled'] = true
        data['medicareEnrolled'] = false
        data['tricareEnrolled'] = false
        data['champvaEnrolled'] = false
      end

      # Required property for :veteran
      data['plannedClinic'] = '568A4' if form_subject == :veteran

      mutations&.call data

      data
    end
    # rubocop:enable Metrics/MethodLength
  end
end
