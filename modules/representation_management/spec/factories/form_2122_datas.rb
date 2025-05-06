# frozen_string_literal: true

FactoryBot.define do
  factory :form_2122_base, class: 'RepresentationManagement::Form2122Base' do
    veteran_first_name { 'Vet' }
    veteran_middle_initial { 'M' }
    veteran_last_name { 'Veteran' }
    veteran_social_security_number { '123456789' }
    veteran_va_file_number { '123456789' }
    veteran_date_of_birth { '1980-12-31' }
    veteran_address_line1 { '123 Fake Veteran St' }
    veteran_city { 'Portland' }
    veteran_country { 'US' }
    veteran_state_code { 'OR' }
    veteran_zip_code { '12345' }
    veteran_zip_code_suffix { '6789' }
    veteran_phone { '5555555555' }
    veteran_email { 'veteran@example.com' }
    veteran_service_number { '123456789' }

    representative_id { 'REP123456' }

    record_consent { true }
    consent_address_change { true }
    consent_limits { %w[ALCOHOLISM DRUG_ABUSE] }

    trait :with_claimant do
      claimant_first_name { 'Claim' }
      claimant_middle_initial { 'M' }
      claimant_last_name { 'Claimant' }
      claimant_date_of_birth { '1980-12-31' }
      claimant_relationship { 'Spouse' }
      claimant_address_line1 { '123 Fake Claimant St' }
      claimant_city { 'Portland' }
      claimant_country { 'US' }
      claimant_state_code { 'OR' }
      claimant_zip_code { '12345' }
      claimant_zip_code_suffix { '6789' }
      claimant_phone { '5555555555' }
      claimant_email { 'claimant@example.com' }
    end
  end

  factory :form_2122_data, class: 'RepresentationManagement::Form2122Data', parent: :form_2122_base do
    organization_id { '123456' }
  end

  factory :form_2122a_data, class: 'RepresentationManagement::Form2122aData', parent: :form_2122_base do
    veteran_service_branch { 'ARMY' }
    consent_inside_access { true }
    consent_outside_access { true }
    consent_team_members { true }
  end
end
