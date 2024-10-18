# frozen_string_literal: true

FactoryBot.define do
  factory :secondary_appeal_form4142, class: 'SecondaryAppealForm' do
    guid { SecureRandom.uuid }
    form_id { '21-4142' }
    form do
      {
        veteran: {
          fullName: {
            first: 'Person',
            last: 'McPerson'
          },
          dateOfBirth: '1983-01-23',
          ssn: '111223333',
          address: {},
          homePhone: '123-456-7890'
        },
        patientIdentification: {
          isRequestingOwnMedicalRecords: true

        },
        providerFacility: [{}],
        preparerIdentification: {
          relationshipToVeteran: 'self'
        },
        acknowledgeToReleaseInformation: true,
        limitedConsent: 'some string',
        privacyAgreementAccepted: true
      }.to_json
    end
    appeal_submission
  end
end
