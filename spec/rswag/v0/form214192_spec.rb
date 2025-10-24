# frozen_string_literal: true

require 'swagger_helper'
require Rails.root.join('spec', 'rswag_override.rb').to_s
require 'rails_helper'

RSpec.describe 'Form 21-4192 API', openapi_spec: 'public/openapi.json', type: :request do
  path '/v0/form214192' do
    post 'Submit a 21-4192 form' do
      before do
        host! Settings.hostname
      end
      
      tags 'benefits_forms'
      operationId 'submitForm214192'
      consumes 'application/json'
      produces 'application/json'
      description 'Submit a Form 21-4192 (Request for Employment Information in Connection with ' \
                  'Claim for Disability Benefits)'

      parameter name: :form, in: :body, schema: {
        type: :object,
        properties: {
          form: {
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

        examples 'application/json' => {
          data: {
            id: '123456',
            type: 'form_submissions',
            attributes: {
              submitted_at: '2024-06-01T12:34:56Z',
              regional_office: [
                'Department of Veterans Affairs',
                'Example Regional Office',
                'P.O. Box 1234',
                'Example City, Wisconsin 12345-6789'
              ],
              confirmation_number: 'ABCDEF123456',
              guid: '550e8400-e29b-41d4-a716-446655440000',
              form: '21-4192'
            }
          }
        }

        let(:form) do
          {
            form: {
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
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['attributes']['form']).to eq('21-4192')
          expect(data['data']['attributes']).to have_key('confirmation_number')
          expect(data['data']['attributes']).to have_key('submitted_at')
        end
      end

      # Validation error response
      response '422', 'Validation error' do
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       detail: { type: :string },
                       code: { type: :string },
                       status: { type: :string }
                     }
                   }
                 }
               }

        examples 'application/json' => {
          errors: [
            {
              title: 'Unprocessable entity',
              detail: "The property '#/' did not contain a required property of 'veteranInformation'",
              code: '422',
              status: '422'
            }
          ]
        }

        let(:form) do
          {
            form: {
              employmentInformation: {
                employerName: 'Acme Corp'
              }
            }
          }
        end

        run_test!
      end

      # Bad request response
      response '400', 'Bad request - missing required parameter' do
        schema type: :object,
               properties: {
                 errors: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       title: { type: :string },
                       detail: { type: :string },
                       code: { type: :string },
                       status: { type: :string }
                     }
                   }
                 }
               }

        examples 'application/json' => {
          errors: [
            {
              title: 'Missing parameter',
              detail: 'The required parameter "form", is missing',
              code: '400',
              status: '400'
            }
          ]
        }

        let(:form) { nil }

        run_test!
      end
    end
  end

  path '/v0/form214192/download_pdf' do
    post 'Download 21-4192 form as PDF' do
      before do
        host! Settings.hostname
        # Mock the PDF generation process
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return('/tmp/test_form_21_4192.pdf')
        allow(File).to receive(:read).with('/tmp/test_form_21_4192.pdf').and_return('PDF_BINARY_CONTENT')
        allow(File).to receive(:exist?).with('/tmp/test_form_21_4192.pdf').and_return(true)
        allow(File).to receive(:delete).with('/tmp/test_form_21_4192.pdf')
      end

      tags 'benefits_forms'
      operationId 'downloadForm214192Pdf'
      description 'Generate and download a filled 21-4192 form as PDF without submitting it'

      parameter name: :form, 
                in: :query, 
                required: true,
                description: 'JSON string containing the form data',
                schema: {
                  type: :string
                },
                example: '{"veteranInformation":{"fullName":{"first":"John","last":"Doe"},"ssn":"123456789","dateOfBirth":"1980-01-01"},"employmentInformation":{"employerName":"Acme Corp","employerAddress":{"street":"123 Main St","city":"Anytown","state":"CA","postalCode":"12345"},"typeOfWorkPerformed":"Software Development","beginningDateOfEmployment":"2015-06-01"}}'

      produces 'application/pdf'

      # Success response
      response '200', 'PDF successfully generated' do
        schema type: :string, format: :binary

        let(:form) do
          {
            veteranInformation: {
              fullName: {
                first: 'John',
                last: 'Doe',
                middle: 'Michael'
              },
              ssn: '123456789',
              dateOfBirth: '1980-01-01'
            },
            employmentInformation: {
              employerName: 'Acme Corp',
              employerAddress: {
                street: '456 Business Blvd',
                city: 'Chicago',
                state: 'IL',
                postalCode: '60601',
                country: 'USA'
              },
              typeOfWorkPerformed: 'Software Development',
              beginningDateOfEmployment: '2015-06-01'
            }
          }.to_json
        end

        run_test! do |response|
          expect(response.headers['Content-Type']).to eq('application/pdf')
          expect(response.headers['Content-Disposition']).to include('attachment')
          expect(response.headers['Content-Disposition']).to include('21-4192_')
        end
      end
    end
  end
end
