# frozen_string_literal: true

veteran_form_data = {
  'veteran' =>
    { 'name' => { 'first' => 'John', 'last' => 'Doe' },
      'ssn' => '123456789',
      'dateOfBirth' => '1980-12-31',
      'postalCode' => '12345' },
  'dependent' => nil
}

dependent_form_data = veteran_form_data.dup.tap do |data|
  data['dependent'] =
    { 'name' => { 'first' => 'John', 'last' => 'Doe' },
      'dateOfBirth' => '1980-12-31',
      'ssn' => '123456789' }
end

FactoryBot.define do
  factory :saved_claim_benefits_intake,
          class: 'AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim' do
    guid { SecureRandom.uuid }
    form_attachment { create(:va_form_pdf) }
    form { veteran_form_data.to_json }

    form_submissions do
      create_list(:form_submission, 1, :pending)
    end

    trait :dependent do
      form { dependent_form_data.to_json }
    end
  end
end
