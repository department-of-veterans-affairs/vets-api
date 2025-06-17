# frozen_string_literal: true

form_data =
  { 'veteran' =>
    { 'name' => { 'first' => 'John', 'middle' => 'Middle', 'last' => 'Doe' },
      'address' => {
        'addressLine1' => '123 Main St',
        'addressLine2' => 'Apt 1',
        'city' => 'Springfield',
        'stateCode' => 'IL',
        'country' => 'US',
        'zipCode' => '62704',
        'zipCodeSuffix' => '6789'
      },
      'ssn' => '123456789',
      'vaFileNumber' => '123456789',
      'dateOfBirth' => '1980-12-31',
      'serviceNumber' => '123456789',
      'serviceBranch' => 'ARMY',
      'phone' => '1234567890',
      'email' => 'veteran@example.com' },
    'dependent' =>
      { 'name' => { 'first' => 'John', 'middle' => 'Middle', 'last' => 'Doe' },
        'address' => {
          'addressLine1' => '123 Main St',
          'addressLine2' => 'Apt 1',
          'city' => 'Springfield',
          'stateCode' => 'IL',
          'country' => 'US',
          'zipCode' => '62704',
          'zipCodeSuffix' => '6789'
        },
        'dateOfBirth' => '1980-12-31',
        'relationship' => 'Spouse',
        'phone' => '1234567890',
        'email' => 'veteran@example.com' } }

FactoryBot.define do
  factory :saved_claim_benefits_intake,
          class: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim' do
    guid { SecureRandom.uuid }
    form_attachment { create(:va_form_pdf) }

    form { form_data.to_json }
  end
end
