# frozen_string_literal: true

form_data =
  {
    'veteran' =>
      { 'name' => { 'first' => 'John', 'last' => 'Doe' },
        'ssn' => '123456789',
        'dateOfBirth' => '1980-12-31',
        'postalCode' => '12345' },
    'dependent' =>
      { 'name' => { 'first' => 'John', 'last' => 'Doe' },
        'dateOfBirth' => '1980-12-31',
        'ssn' => '123456789' }
  }

FactoryBot.define do
  factory :saved_claim_benefits_intake,
          class: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim' do
    guid { SecureRandom.uuid }
    form_attachment { create(:va_form_pdf) }

    form { form_data.to_json }
  end
end
