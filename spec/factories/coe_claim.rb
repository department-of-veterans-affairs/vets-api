# frozen_string_literal: true

FactoryBot.define do
  factory :coe_claim, class: 'SavedClaim::CoeClaim' do
    form_id { '26-1880' }

    form {
      {
        status: 'RECEIVED',
        veteran: {
          firstName: 'ZOE',
          middleName: 'J',
          lastName: 'MILLER',
          suffixName: 'IV',
          dateOfBirth: 638_928_000,
          vetAddress1: 'VETERAN CONTACT ADDRESS LINE1',
          vetAddress2: 'VETERAN CONTACT ADDRESS LINE 2',
          vetCity: 'VETERAN CONTACT CITY',
          vetState: 'VA',
          vetZip: '12345',
          vetZipSuffix: '1234',
          mailingAddress1: 'MAIL CERTIFICATE ADDRESS LINE 1',
          mailingAddress2: 'MAIL CERTIFICATE ADDRESS LINE 2',
          mailingCity: 'MAIL CERTIFICATE CITY',
          mailingState: 'VA',
          mailingZip: '12345',
          mailingZipSuffix: '1234',
          contactPhone: '8008271000',
          contactEmail: 'vets.gov.user+71@gmail.com',
          vaLoanIndicator: true,
          vaHomeOwnIndicator: true,
          activeDutyIndicator: false,
          disabilityIndicator: false
        },
        relevantPriorLoans: [
          {
            vaLoanNumber: nil,
            startDate: 62_125_380_000_000,
            paidOffDate: nil,
            loanAmount: nil,
            loanEntitlementCharged: nil,
            propertyOwned: false,
            oneTimeRestorationRequested: true,
            irrrlRequested: false,
            cashoutRefinaceRequested: false,
            homeSellIndicator: nil,
            noRestorationEntitlementIndicator: false,
            propertyAddress1: 'LOAN STREET ADDRESS',
            propertyAddress2: nil,
            propertyCity: 'LOAN CITY',
            propertyState: nil,
            propertyCounty: 'USA',
            propertyZip: nil,
            propertyZipSuffix: nil
          }
        ],
        periodsOfService: [
          {
            enteredOnDuty: 946_706_400_000,
            releasedActiveDuty: 1_262_325_600_000,
            serviceType: 'ACTIVE_DUTY',
            characterOfService: nil,
            militaryBranch: nil,
            activeDutyPoints: '0',
            inactiveDutyPoints: '0',
            qualifies: nil,
            rankCode: 'OFFICER',
            disabilityIndicator: false
          },
          {
            enteredOnDuty: 1_293_861_600_000,
            releasedActiveDuty: 1_609_480_800_000,
            serviceType: 'ACTIVE_DUTY',
            characterOfService: nil,
            militaryBranch: nil,
            activeDutyPoints: '0',
            inactiveDutyPoints: '0',
            qualifies: nil,
            rankCode: 'OFFICER',
            disabilityIndicator: false
          }
        ]
      }.to_json
    }
  end
end
