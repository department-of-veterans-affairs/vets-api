# frozen_string_literal: true

# The module provides a method to save generated data to a JSON file,
# useful for seeding databases or loading mock data during development.
#
# Using the generator in the Rails console:
# 1. Start the console: `bundle exec rails c`.
# 2. Load the generator:
#    `require Rails.root.join('modules/accredited_representative_portal',
#                             'spec/support/poa_record_generator.rb')`.
# 3. Generate POA records: `PoaRecordGenerator.generate(num_records: 30)`.
# 4. Save to a file: `PoaRecordGenerator.generate_and_save_to_file(num_records: 30, file_path: 'modules/accredited_representative_portal/spec/fixtures/poa_records.json')`.
module PoaRecordGenerator
  class << self
    require 'faker'
    require 'json'

    # Generates a hash with POA request records and associated metadata.
    # @param num_records [Integer] The number of POA records to generate.
    # @return [Hash] A hash containing the generated records and metadata.
    def generate(num_records: 30)
      Faker::UniqueGenerator.clear

      data = num_records.times.map do |i|
        status = i < 25 ? 'pending' : %w[obsolete expired canceled].sample
        {
          id: Faker::Number.unique.number(digits: 10).to_s,
          type: 'powerOfAttorneyRequest',
          attributes: generate_attributes(i, status)
        }
      end

      { data:, }
    end

    # Generates POA request records and saves them to a specified JSON file.
    # @param num_records [Integer] The number of POA records to generate.
    # @param file_path [String] The file path to write the JSON data to.
    def generate_and_save_to_file(num_records: 30,
                                  file_path: 'modules/accredited_representative_portal/spec/fixtures/poa_records.json')
      poa_data = generate(num_records:)
      File.write(file_path, JSON.pretty_generate(poa_data))
    end

    private

    def generate_attributes(index, status)
      {
        status: status,
        declinedReason: status == 'pending' ? nil : Faker::Lorem.sentence,
        powerOfAttorneyCode: index.even? ? '012' : '034',
        submittedAt: Faker::Date.backward(days: 30).iso8601,
        acceptedOrDeclinedAt: status == 'pending' ? nil : Faker::Date.forward(days: 30).iso8601,
        isAddressChangingAuthorized: index.even? ? true : false,
        isTreatmentDisclosureAuthorized: index.odd? ? true : false,
        representative: generate_representative,
        claimant: generate_claimant,
        claimantAddress: generate_claimant_address
      }
    end

    def generate_claimant
      {
        firstName: Faker::Name.first_name,
        lastName: Faker::Name.last_name,
        participantId: Faker::Number.unique.number(digits: 10).to_s,
        relationshipToVeteran: %w[Spouse Child Parent Friend].sample
      }
    end

    def generate_claimant_address
      {
        city: Faker::Address.city,
        state: Faker::Address.state_abbr,
        zip: Faker::Address.zip,
        country: Faker::Address.country,
        militaryPostOffice: nil,
        militaryPostalCode: nil
      }
    end

    def generate_representative
      {
        email: Faker::Internet.email,
        firstName: Faker::Name.first_name,
        lastName: Faker::Name.last_name
      }
    end
  end
end
