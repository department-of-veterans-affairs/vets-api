# frozen_string_literal: true

FactoryBot.define do
  factory :va0976, class: 'SavedClaim::EducationBenefits::VA0976', parent: :education_benefits do
    form do
      {
        'designatingOfficial' => {
          'fullName' => {
            'first' => 'John',
            'middle' => 'A',
            'last' => 'Doe'
          },
          'title' => 'Designating Official',
          'emailAddress' => 'john.doe@example.com',
          'phoneNumber' => '5556071234'
        },
        'institutionDetails' => {
          'hasVaFacilityCode' => true,
          'facilityCode' => '12345678',
          'institutionName' => 'Test University',
          'institutionAddress' => {
            'country' => 'USA',
            'street' => '123 Main St',
            'city' => 'Anytown',
            'state' => 'CA',
            'postalCode' => '12345'
          }
        },
        'primaryOfficialDetails' => {
          'fullName' => {
            'first' => 'Jane',
            'middle' => 'B',
            'last' => 'Smith'
          },
          'title' => 'Primary Certifying Official',
          'emailAddress' => 'jane.smith@example.com',
          'phoneNumber' => '5556071234'
        },
        'primaryOfficialTraining' => {
          'trainingCompletionDate' => '2024-03-15',
          'trainingExempt' => false
        },
        'primaryOfficialBenefitStatus' => {
          'hasVaEducationBenefits' => true
        },
        'statementOfTruthSignature' => 'John A Doe',
        'dateSigned' => '2024-03-15'
      }.to_json
    end
  end
end
