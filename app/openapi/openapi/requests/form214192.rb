# frozen_string_literal: true

module Openapi
  module Requests
    class Form214192
      FORM_SCHEMA = {
        '$schema': 'json-schemer://openapi30/schema',
        type: :object,
        properties: {
          veteranInformation: {
            type: :object,
            required: %i[fullName dateOfBirth],
            properties: {
              fullName: { '$ref' => '#/components/schemas/FirstMiddleLastName' },
              ssn: {
                type: :string,
                pattern: '^\d{9}$',
                description: 'Social Security Number (9 digits)',
                example: '123456789'
              },
              vaFileNumber: { type: :string, example: '987654321' },
              dateOfBirth: { type: :string, format: :date, example: '1980-01-01' },
              address: { '$ref' => '#/components/schemas/SimpleAddress' }
            }
          },
          employmentInformation: {
            type: :object,
            required: %i[employerName employerAddress typeOfWorkPerformed
                         beginningDateOfEmployment],
            properties: {
              employerName: { type: :string },
              employerAddress: { '$ref' => '#/components/schemas/SimpleAddress' },
              typeOfWorkPerformed: { type: :string },
              beginningDateOfEmployment: { type: :string, format: :date },
              endingDateOfEmployment: { type: :string, format: :date },
              amountEarnedLast12MonthsOfEmployment: { type: :number },
              timeLostLast12MonthsOfEmployment: { type: :string },
              hoursWorkedDaily: { type: :number },
              hoursWorkedWeekly: { type: :number },
              concessions: { type: :string },
              terminationReason: { type: :string },
              dateLastWorked: { type: :string, format: :date },
              lastPaymentDate: { type: :string, format: :date },
              lastPaymentGrossAmount: { type: :number },
              lumpSumPaymentMade: { type: :boolean },
              grossAmountPaid: { type: :number },
              datePaid: { type: :string, format: :date }
            }
          },
          militaryDutyStatus: {
            type: :object,
            properties: {
              currentDutyStatus: { type: :string },
              veteranDisabilitiesPreventMilitaryDuties: { type: :boolean }
            }
          },
          benefitEntitlementPayments: {
            type: :object,
            properties: {
              sickRetirementOtherBenefits: { type: :boolean },
              typeOfBenefit: { type: :string },
              grossMonthlyAmountOfBenefit: { type: :number },
              dateBenefitBegan: { type: :string, format: :date },
              dateFirstPaymentIssued: { type: :string, format: :date },
              dateBenefitWillStop: { type: :string, format: :date },
              remarks: { type: :string }
            }
          },
          certification: {
            type: :object,
            required: %i[signature certified],
            properties: {
              signature: {
                type: :string,
                description: 'Signature of employer or supervisor',
                example: 'John Doe'
              },
              certified: {
                type: :boolean,
                enum: [true],
                description: 'Certified by the employer or supervisor (must be true)',
                example: true
              }
            }
          }
        },
        required: %i[veteranInformation employmentInformation certification]
      }.freeze
    end
  end
end
