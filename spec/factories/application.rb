# frozen_string_literal: true

FactoryBot.define do
  factory :application do
    form_id '40-10007'
    form do
      {
        privacyAgreementAccepted: true,
        applicant: {
          applicantEmail: 'foo@foo.com',
          applicantPhoneNumber: '2342342342',
          applicantRelationshipToClaimant: 'Self',
          mailingAddress: {
            country: 'USA',
            state: 'CA',
            postalCode: '90210',
            street: '123 Main St',
            city: 'Anytown'
          },
          name: {
            first: 'Test',
            last: 'User'
          }
        },
        claimant: {
          address: {
            country: 'USA',
            state: 'CA',
            postalCode: '90210',
            street: '123 Main St',
            city: 'Anytown'
          },
          dateOfBirth: '1990-03-04',
          desiredCemetery: {
            id: '121',
            label: 'ASHLAND CEMETERY'
          },
          email: 'foo@foo.com',
          name: {
            first: 'Test',
            last: 'User'
          },
          phoneNumber: '2342342342',
          relationshipToVet: '3',
          ssn: '987-98-7987',
          hasCurrentlyBuried: '2'
        },
        veteran: {
          address: {
            country: 'USA'
          },
          currentName: {
            first: 'Test',
            last: 'User'
          },
          serviceName: {
            first: 'Test',
            last: 'User'
          },
          gender: 'Female',
          isDeceased: 'no',
          maritalStatus: 'Single',
          militaryStatus: 'A',
          serviceRecords: [
            {
              dateRange: {},
              serviceBranch: 'C7'
            }
          ],
          ssn: '987-98-7987'
        }
      }.to_json
    end
  end
end
