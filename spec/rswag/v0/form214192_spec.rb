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

      parameter name: :form_data, in: :body, required: true, schema: {
        type: :object,
        properties: {
          veteranInformation: {
            type: :object,
            required: %i[fullName dateOfBirth],
            properties: {
              fullName: Openapi::Schemas::Name::FIRST_MIDDLE_LAST,
              ssn: {
                type: :string,
                pattern: '^\d{9}$',
                description: 'Social Security Number (9 digits)',
                example: '123456789'
              },
              vaFileNumber: { type: :string, example: '987654321' },
              dateOfBirth: { type: :string, format: :date, example: '1980-01-01' },
              address: Openapi::Schemas::Address::SIMPLE_ADDRESS
            }
          },
          employmentInformation: {
            type: :object,
            required: %i[employerName employerAddress typeOfWorkPerformed
                         beginningDateOfEmployment],
            properties: {
              employerName: { type: :string },
              employerAddress: Openapi::Schemas::Address::SIMPLE_ADDRESS.merge(
                required: %i[street city state postalCode country]
              ),
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
        },
        required: %i[veteranInformation employmentInformation]
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

        before do
          # Stub to return static values for reproducible OpenAPI docs
          allow(SecureRandom).to receive(:uuid).and_return('12345678-1234-1234-1234-123456789abc')
          allow(Time).to receive(:current).and_return(Time.zone.parse('2025-01-15 10:30:00 UTC'))
        end

        let(:form_data) do
          {
            veteranInformation: {
              fullName: {
                first: 'John',
                last: 'Doe',
                middle: 'A'
              },
              ssn: '123456789',
              dateOfBirth: '1980-01-01',
              address: {
                street: '123 Main St',
                street2: 'Apt 4B',
                city: 'Springfield',
                state: 'IL',
                postalCode: '62701',
                country: 'US'
              }
            },
            employmentInformation: {
              employerName: 'Acme Corp',
              employerAddress: {
                street: '456 Business Blvd',
                street2: nil,
                city: 'Chicago',
                state: 'IL',
                postalCode: '60601',
                country: 'US'
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

      response '422', 'Unprocessable Entity - schema validation failed' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:form_data) do
          {
            veteranInformation: {
              fullName: { first: 'OnlyFirst' }
            }
          }
        end

        it 'returns a 422 when request body fails schema validation' do |example|
          submit_request(example.metadata)
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end
  end
end
