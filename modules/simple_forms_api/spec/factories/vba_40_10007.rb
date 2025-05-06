# frozen_string_literal: true

FactoryBot.define do
    # rubocop:disable Layout/IndentationWidth
    factory :vba4010007, class: 'SimpleFormsApi::VBA4010007' do
      application {
        {
          'preneed_attachments' => [
            {
              'name' => '123.jpeg',
              'size' => 80,
              'confirmation_code' => 'a-random-uuid'
            }
          ],
          'applicant' => {
            'applicant_relationship_to_claimant' => 'Self',
            'mailing_address' => {
              'street' => '123 Elm St',
              'street2' => 'APT 2B',
              'city' => 'Springwood',
              'country' => 'USA',
              'state' => 'OH',
              'postal_code' => '23432'
            },
            'name' => {
              'first' => 'john',
              'last' => 'stockton'
            },
            'applicant_phone_number' => '3125555678'
          },
          'currently_buried_persons' => [
            { 'name' => { 'first' => 'Ben', 'last' => 'Fitz' } },
            { 'name' => { 'first' => 'Ben', 'last' => 'Fitz' } },
            { 'name' => { 'first' => 'Freddy', 'last' => 'Kruger' } },
            { 'name' => { 'first' => 'Ben', 'last' => 'Fitz' } }
          ],
          'claimant' => {
            'desired_cemetery' => '915',
            'address' => {
              'street' => '123 Elm St',
              'street2' => 'APT 2B',
              'city' => 'Springwood',
              'country' => 'USA',
              'state' => 'OH',
              'postal_code' => '23432'
            },
            'phone_number' => '3125555678',
            'email' => 'test@test.com',
            'name' => {
              'first' => 'Lee',
              'middle' => 'Ishmael Bender',
              'last' => 'Gordon',
              'suffix' => 'IV',
              'maiden' => 'Uriel Benjamin'
            },
            'ssn' => '134-51-2996',
            'date_of_birth' => '2016-10-27',
            'relationship_to_vet' => '2'
          },
          'has_currently_buried' => '2',
          'veteran' => {
            'service_records' => [
              {
                'date_range' => { 'from' => '1990-01-01', 'to' => '2000-02-03' },
                'service_branch' => 'CV',
                'discharge_type' => '1',
                'highest_rank' => 'Lord Commander of a'
              },
              {
                'date_range' => { 'from' => '1990-01-01', 'to' => '2000-02-03' },
                'service_branch' => 'AR',
                'discharge_type' => '3',
                'highest_rank' => 'Lord Commander of b'
              },
              {
                'date_range' => { 'from' => '1990-01-01', 'to' => '2000-02-03' },
                'service_branch' => 'CI',
                'discharge_type' => '4',
                'highest_rank' => 'Lord Commander of c'
              }
            ],
            'address' => {
              'street' => '123 Elm St',
              'street2' => 'APT 2B',
              'city' => 'Springwood',
              'country' => 'CAN',
              'state' => 'OH',
              'postal_code' => '23432'
            },
            'is_deceased' => 'Yes',
            'military_status' => 'S',
            'date_of_birth' => '2016-10-27',
            'current_name' => {
              'first' => 'Quinlan',
              'middle' => 'Tucker Strong',
              'last' => 'Short',
              'suffix' => 'III',
              'maiden' => 'Quin Solis'
            },
            'ssn' => '234-34-3456',
            'gender' => 'Male',
            'race' => { 'is_asian' => true },
            'service_name' => {
              'first' => 'Quinlan',
              'middle' => 'Tucker Strong',
              'last' => 'Short',
              'suffix' => 'III'
            },
            'marital_status' => 'Divorced',
            'place_of_birth' => 'Adipisci'
          }
        }
      }
      privacy_agreement_accepted { true }
      form_number { '40-10007' }
      initialize_with { new(attributes.stringify_keys) }
    end
  # rubocop:enable Layout/IndentationWidth
end
