# frozen_string_literal: true

FactoryBot.define do
  factory :vic_submission, class: VIC::VICSubmission do
    form do
      {
        'serviceBranch' => 'F',
        'email' => 'foo@foo.com',
        'dd214' => [
          {
            'confirmationCode' => create(:supporting_documentation_attachment).guid
          }
        ],
        'photo' => {
          'confirmationCode' => create(:profile_photo_attachment).guid
        },
        'privacyAgreementAccepted' => true,
        'veteranDateOfBirth' => '1985-03-07',
        'veteranFullName' => {
          'first' => 'Mark',
          'last' => 'Olson'
        },
        'veteranAddress' => {
          'city' => 'Milwaukee',
          'country' => 'USA',
          'postalCode' => '53130',
          'state' => 'WI',
          'street' => '123 Main St'
        },
        'veteranSocialSecurityNumber' => '111223333',
        'phone' => '5551110000',
        'gender' => 'M'
      }.to_json
    end
  end
end
