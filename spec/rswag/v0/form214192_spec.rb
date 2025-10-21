# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21-4192 API', openapi_spec: 'public/openapi.json', type: :request do
  path '/v0/form214192' do
    post 'Submit a 21-4192 form' do
      tags 'benefits_forms'
      operationId 'submitForm214192'
      consumes 'application/json'
      produces 'application/json'
      description 'Submit a Form 21-4192 (Request for Employment Information in Connection with ' \
                  'Claim for Disability Benefits)'

      parameter name: :form_data, in: :body, schema: {
        type: :object,
        properties: {
          veteranInformation: {
            type: :object,
            required: %i[fullName dateOfBirth],
            properties: {
              fullName: {
                type: :object,
                properties: {
                  first: { type: :string, example: 'John' },
                  last: { type: :string, example: 'Doe' },
                  middle: { type: :string, example: 'Michael' }
                },
                required: %i[first last]
              },
              ssn: {
                type: :string,
                pattern: '^\d{9}$',
                description: 'Social Security Number (9 digits)',
                example: '123456789'
              },
              vaFileNumber: { type: :string, example: '987654321' },
              dateOfBirth: { type: :string, format: :date, example: '1980-01-01' },
              address: {
                type: :object,
                properties: {
                  street: { type: :string, example: '123 Main St' },
                  street2: { type: :string, example: 'Apt 4B' },
                  city: { type: :string, example: 'Anytown' },
                  state: { type: :string, example: 'CA' },
                  postalCode: { type: :string, example: '12345' },
                  country: { type: :string, example: 'USA' }
                },
                required: %i[street city state postalCode country]
              }
            }
          },
          employmentInformation: {
            type: :object,
            required: %i[employerName employerAddress typeOfWorkPerformed
                         beginningDateOfEmployment],
            properties: {
              employerName: { type: :string },
              employerAddress: {
                type: :object,
                properties: {
                  street: { type: :string, example: '456 Business Blvd' },
                  street2: { type: :string, example: 'Suite 200' },
                  city: { type: :string, example: 'Chicago' },
                  state: { type: :string, example: 'IL' },
                  postalCode: { type: :string, example: '60601' },
                  country: { type: :string, example: 'USA' }
                },
                required: %i[street city state postalCode country]
              },
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
          }
        }
      }

      # Success response
      response '200', 'Form successfully submitted' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string },
                     attributes: {
                       type: :object,
                       properties: {
                         submitted_at: { type: :string, format: 'date-time' },
                         regional_office: {
                           type: :array,
                           items: { type: :string },
                           example: [
                             'Department of Veterans Affairs',
                             'Example Regional Office',
                             'P.O. Box 1234',
                             'Example City, Wisconsin 12345-6789'
                           ]
                         },
                         confirmation_number: { type: :string },
                         guid: { type: :string },
                         form: { type: :string }
                       }
                     }
                   }
                 }
               },
               required: [:data]

        let(:form_data) do
          {
            veteranInformation: {
              fullName: {
                first: 'John',
                last: 'Doe',
                middle: 'Michael'
              },
              ssn: '123456789',
              dateOfBirth: '1980-01-01',
              address: {
                street: '123 Main St',
                street2: 'Apt 4B',
                city: 'Springfield',
                state: 'IL',
                postalCode: '62701',
                country: 'USA'
              }
            },
            employmentInformation: {
              employerName: 'Acme Corp',
              employerAddress: {
                street: '456 Business Blvd',
                street2: 'Suite 200',
                city: 'Chicago',
                state: 'IL',
                postalCode: '60601',
                country: 'USA'
              },
              typeOfWorkPerformed: 'Software Development',
              beginningDateOfEmployment: '2015-06-01'
            }
          }
        end

        it 'returns a successful response with form submission data' do |example|
          submit_request(example.metadata)
          example.metadata[:response][:content] = {
            'application/json' => {
              example: JSON.parse(response.body, symbolize_names: true)
            }
          }
          assert_response_matches_metadata(example.metadata)
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
