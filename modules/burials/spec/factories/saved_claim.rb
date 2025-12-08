# frozen_string_literal: true

FactoryBot.define do
  factory :burials_saved_claim, class: 'Burials::SavedClaim' do
    form_id { '21P-530EZ' }
    form do
      {
        privacyAgreementAccepted: true,
        # Veteran Information
        veteranFullName: {
          first: 'WESLEY',
          middle: 'M',
          last: 'FORD'
        },
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '796043735',
        vaFileNumber: '12345678',
        deathDate: '1989-12-13',
        burialDate: '1990-01-15',
        # Previous Names
        previousNames: [
          {
            first: 'John',
            middle: 'A',
            last: 'Smith',
            serviceBranch: 'army'
          }
        ],
        # Military Service
        militaryServiceNumber: '123456789',
        toursOfDuty: [
          {
            serviceBranch: 'Air Force',
            dateRangeStart: '2000-01-15',
            dateRangeEnd: '2004-12-20',
            placeOfEntry: 'Los Angeles, CA',
            placeOfSeparation: 'San Diego, CA',
            rank: 'E-5',
            unit: '101st Airborne',
            militaryServiceNumber: '987654321'
          }
        ],
        # Location of Death
        locationOfDeath: {
          location: 'vaMedicalCenter'
        },
        vaMedicalCenter: {
          facilityName: 'VA Medical Center - Los Angeles',
          facilityLocation: 'Los Angeles, CA'
        },
        stateVeteransHome: {
          facilityName: nil,
          facilityLocation: nil
        },
        homeHospiceCare: false,
        homeHospiceCareAfterDischarge: false,
        # Claimant Information
        claimantFullName: {
          first: 'Derrick',
          middle: 'A',
          last: 'Stewart'
        },
        claimantSocialSecurityNumber: '123456789',
        claimantDateOfBirth: '1990-03-15',
        claimantEmail: 'foo@foo.com',
        claimantPhone: '555-123-4567',
        claimantIntPhone: nil,
        claimantAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          street2: 'Apt 4B',
          city: 'Anytown'
        },
        relationshipToVeteran: 'spouse',
        # Burial Location
        finalRestingPlace: {
          location: 'cemetery'
        },
        nationalOrFederal: true,
        name: 'National Cemetery',
        cemetaryLocationQuestion: 'cemetery',
        cemeteryLocation: {
          name: 'State Veterans Cemetery',
          zip: '90210'
        },
        tribalLandLocation: {
          name: nil,
          zip: nil
        },
        # Government Contributions
        govtContributions: true,
        amountGovtContribution: '5000',
        # Benefit Claims
        burialAllowance: true,
        plotAllowance: true,
        transportation: true,
        burialAllowanceRequested: {
          nonService: true,
          service: false,
          unclaimed: false
        },
        # Expenses & Allowances
        previouslyReceivedAllowance: false,
        burialExpenseResponsibility: false,
        plotExpenseResponsibility: true,
        transportationExpenses: true,
        # Unclaimed Remains
        confirmation: {
          checkBox: false
        },
        # Process Options
        processOption: false,
        firmNameAndAddr: nil,
        officialPosition: nil,
        deathCertificate: [
          {
            name: 'certificate.pdf',
            confirmationCode: 'abc-123-def',
            attachmentId: '',
            isEncrypted: false
          }
        ]
      }.to_json
    end

    trait :pending do
      after(:create) do |claim|
        create(:lighthouse_submission, :pending, saved_claim_id: claim.id, form_id: claim.form_id)
      end
    end

    trait :submitted do
      after(:create) do |claim|
        create(:lighthouse_submission, :submitted, saved_claim_id: claim.id, form_id: claim.form_id)
      end
    end

    trait :failure do
      after(:create) do |claim|
        create(:lighthouse_submission, :failure, saved_claim_id: claim.id, form_id: claim.form_id)
      end
    end
  end
end
