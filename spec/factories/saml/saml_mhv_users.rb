# frozen_string_literal: true

FactoryBot.define do
  factory :saml_mhv_user, class: Saml::MhvUser do
    mhv_icn '1012853550V207686'
    mhv_profile do
      {
        'accountType' => 'Premium',
        'availableServices' => {
          '21' => 'VA Medications',
          '4' => 'Secure Messaging',
          '3' => 'VA Allergies',
          '2' => 'Rx Refill',
          '12' => 'Blue Button (all VA data)',
          '1' => 'Blue Button self entered data.',
          '11' => 'Blue Button (DoD) Military Service Information'
        }
      }.to_json
    end
    mhv_uuid '12345748'

    uuid                '0e1bb5723d7c4f0686f46ca4505642ad'
    email               'kam+tristanmhv@adhocteam.us'
    multifactor         'false'
    level_of_assurance  nil

    skip_create
  end
end
