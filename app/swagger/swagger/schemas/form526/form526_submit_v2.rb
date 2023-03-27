# frozen_string_literal: true

module Swagger
  module Schemas
    module Form526
      class Form526SubmitV2
        include Swagger::Blocks

        DATE_PATTERN = /^(\\d{4}|XXXX)-(0[1-9]|1[0-2]|XX)-(0[1-9]|[1-2][0-9]|3[0-1]|XX)$/
        ADDRESS_PATTERN = /^([-a-zA-Z0-9'.,&#]([-a-zA-Z0-9'.,&# ])?)+$/

        swagger_schema :Form526SubmitV2 do
          key :required, [:form526]

          property :form526, type: :object do
            property :alternateNames, type: :array do
              items type: :object do
                key :$ref, :AlternateName
              end
            end
            property :atRiskHousingSituation, type: :string, enum:
              %w[
                losingHousing
                leavingShelter
                other
              ]
            property :attachments, type: :array do
              items type: :object do
                key :$ref, :Attachment
              end
            end
            property :bankAccountNumber, type: :string, minLength: 4, maxLength: 17
            property :bankAccountType, type: :string, enum:
              %w[
                Checking
                Saving
              ]
            property :bankName, type: :string, maxLength: 35
            property :bankRoutingNumber, type: :string, pattern: /^\d{9}$/
            property :completedFormAttachments, type: :array do
              items type: :object do
                key :required, %i[name attachmentId]
                property :name, type: :string, example: 'private_medical_record.pdf'
                property :confirmationCode, type: :string, example: 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a1'
                property :attachmentId, type: :string
              end
            end
            property :confinements, type: :array do
              items do
                key :$ref, :DateRangeAllRequired
              end
            end
            property :employmentRequestAttachments, type: :array do
              items type: :object do
                key :required, %i[name attachmentId]
                property :name, type: :string, example: 'private_medical_record.pdf'
                property :confirmationCode, type: :string, example: 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a1'
                property :attachmentId, type: :string, enum: ['L115']
              end
            end
            property :form0781, type: :object do
              key :$ref, :Form0781
            end
            property :form4142, type: :object do
              key :$ref, :Form4142
            end
            property :form8940, type: :object do
              key :$ref, :Form8940
            end
            property :forwardingAddress, type: :object do
              key :$ref, :ForwardingAddress
            end
            property :hasTrainingPay, type: :boolean
            property :homelessHousingSituation, type: :string, enum:
              %w[
                shelter
                notShelter
                anotherPerson
                other
              ]
            property :homelessOrAtRisk, type: :string, enum:
              %w[
                no
                homeless
                atARisk
              ]
            property :homelessnessContact, type: :object do
              property :name,
                       type: :string,
                       minLength: 1,
                       maxLength: 100,
                       pattern: %r{^([a-zA-Z0-9\-/']+( ?))*$}
              property :phoneNumber,
                       type: :string,
                       pattern: /^\\d{10}$/
            end
            property :isVaEmployee, type: :boolean
            property :mailingAddress, type: :object do
              key :$ref, :AddressRequiredFields
            end
            property :mentalChanges, type: :object do
              key :$ref, :MentalChanges
            end
            property :militaryRetiredPayBranch, type: :string, enum:
              [
                'Air Force',
                'Army',
                'Coast Guard',
                'Marine Corps',
                'National Oceanic and Atmospheric Administration',
                'Navy',
                'Public Health Service'
              ]
            property :needToLeaveHousing, type: :boolean
            property :newPrimaryDisabilities, type: :array do
              items type: :object do
                key :$ref, :NewDisability
              end
            end
            property :newSecondaryDisabilities, type: :array do
              items type: :object do
                key :$ref, :NewDisability
              end
            end
            property :otherAtRiskHousing, type: :string, minLength: 1, maxLength: 500
            property :otherHomelessHousing, type: :string
            property :phoneAndEmail, type: :object do
              key :required, %i[primaryPhone emailAddress]

              property :primaryPhone,
                       type: :string,
                       pattern: /^\\d{10}$/
              property :emailAddress,
                       type: :string,
                       minLength: 6,
                       maxLength: 80,
                       pattern: /^[_A-Za-z0-9-]+(\\.[_A-Za-z0-9-]+)*@[A-Za-z0-9-]+(\\.[A-Za-z0-9]+)*(\\.[A-Za-z]{2,})$/
            end
            property :privateMedicalRecordAttachments, type: :array do
              items type: :object do
                key :$ref, :PrivateMedicalRecordAttachment
              end
            end
            property :ratedDisabilities,
                     type: :array,
                     minItems: 1,
                     maxItems: 100 do
              items type: :object do
                key :$ref, :RatedDisability
              end
            end
            property :secondaryAttachment, type: :array do
              items type: :object do
                key :$ref, :SecondaryAttachment
              end
            end
            property :separationPayBranch, type: :string, enum:
              [
                'VA Form 21-0781a - Statement in Support of Claim for PTSD Secondary to Personal Assault',
                'Civilian Police Reports',
                'Military Personnel Record',
                'Medical Treatment Record - Government Facility',
                'Medical Treatment Record - Non-Government Facility',
                'DD214',
                'Other Correspondence',
                'Buddy/Lay Statement'
              ]
            property :separationPayDate, type: :string
            property :serviceInformation, type: :object do
              items do
                key :$ref, :ServiceInformation
              end
            end
            property :standardClaim, type: :boolean, default: false
            property :unemployabilityAttachments, type: :array do
              items type: :object do
                key :$ref, :UnemployabilityAttachments
              end
            end
            property :vaTreatmentFacilities, type: :array do
              items type: :object do
                key :$ref, :VATreatmentFacility
              end
            end
            property :waiveRetirementPay, type: :boolean
            property :waiveTrainingPay, type: :boolean
          end
        end

        swagger_schema :Attachment do
          key :required, %i[name attachmentId]
          property :name, type: :string, example: 'private_medical_record.pdf'
          property :confirmationCode, type: :string, example: 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a1'
          property :attachmentId, type: :string, enum:
            %w[
              L015
              L018
              L029
              L702
              L703
              L034
              L478
              L048
              L049
              L023
              L070
              L450
              L451
              L222
              L228
              L229
              L102
              L107
              L827
              L115
              L117
              L159
              L133
              L139
              L149
            ]
        end

        swagger_schema :AlternateName do
          property :first,
                   type: :string,
                   example: 'John',
                   minLength: 1,
                   maxLength: 14,
                   pattern: %r{^([a-zA-Z0-9\-/']+( ?))+$}
          property :middle,
                   type: :string,
                   example: 'Jonny',
                   minLength: 1,
                   maxLength: 14,
                   pattern: %r{^([a-zA-Z0-9\-/']+( ?))+$}
          property :last,
                   type: :string,
                   example: 'Johnson',
                   minLength: 1,
                   maxLength: 14,
                   pattern: %r{^([a-zA-Z0-9\-/']+( ?))+$}
        end

        swagger_schema :ForwardingAddress do
          # See link for country enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
          property :country, type: :string, example: 'USA'
          property :addressLine1,
                   type: :string,
                   maxLength: 35,
                   pattern: ADDRESS_PATTERN
          property :addressLine2,
                   type: :string,
                   maxLength: 35,
                   pattern: ADDRESS_PATTERN
          property :addressLine3,
                   type: :string,
                   maxLength: 35,
                   pattern: ADDRESS_PATTERN
          property :city,
                   type: :string,
                   maxLength: 30,
                   pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
          # See link for state enum
          # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
          property :state, type: :string, example: 'OR'
          property :zipCode,
                   type: :string,
                   pattern: /^\\d{5}(?:([-\\s]?)\\d{4})?$/
          property :effectiveDate, type: :object do
            key :$ref, :DateRange
          end
        end

        swagger_schema :MentalChanges do
          property :depression, type: :boolean
          property :obsessive, type: :boolean
          property :prescription, type: :boolean
          property :substance, type: :boolean
          property :hypervigilance, type: :boolean
          property :agoraphobia, type: :boolean
          property :fear, type: :boolean
          property :other, type: :boolean
          property :otherExplanation, type: :string
          property :noneApply, type: :boolean
        end

        swagger_schema :PrivateMedicalRecordAttachment do
          key :required, %i[name attachmentId]

          property :name, type: :string
          property :confirmationCode, type: :string
          property :attachmentId, type: :string, enum: %w[L107 L023]
        end

        swagger_schema :SecondaryAttachment do
          key :required, %i[name attachmentId]

          property :name, type: :string
          property :confirmationCode, type: :string
          property :attachmentId, type: :string, enum:
            %w[
              L229
              L018
              L034
              L048
              L049
              L029
              L023
              L015
            ]
        end

        swagger_schema :ServiceInformation do
          key :required, [:servicePeriods]

          property :servicePeriods,
                   type: :array,
                   minItems: 1,
                   maxItems: 100 do
            items type: :object do
              key :required, %i[serviceBranch dateRange]

              property :serviceBranch, type: :string, enum:
                [
                  'Air Force',
                  'Air Force Reserve',
                  'Air National Guard',
                  'Army',
                  'Army National Guard',
                  'Army Reserve',
                  'Coast Guard',
                  'Coast Guard Reserve',
                  'Marine Corps',
                  'Marine Corps Reserve',
                  'NOAA',
                  'Navy',
                  'Navy Reserve',
                  'Public Health Service'
                ]
              property :dateRange, type: :array do
                items do
                  key :$ref, :DateRangeAllRequired
                end
              end
            end
          end

          property :separationLocation, type: :object do
            items do
              property :separationLocationCode,
                       type: :string,
                       example: '98283'
              property :separationLocationName,
                       type: :string,
                       maxLength: 256,
                       pattern: %r{^([a-zA-Z0-9/\-'.#,*()&][a-zA-Z0-9/\-'.#,*()& ]?)*$},
                       example: 'AF Academy'
            end
          end

          property :reservesNationalGuardService, type: :object do
            items do
              key :required, %i[unitName obligationTermOfServiceDateRange]

              property :unitName,
                       type: :string,
                       maxLength: 256,
                       pattern: /^([a-zA-Z0-9\-'.#][a-zA-Z0-9\-'.# ]?)*$/
              property :obligationTermOfServiceDateRange, type: :array do
                items do
                  key :$ref, :DateRangeAllRequired
                end
              end
              property :receivingTrainingPay, type: :boolean
              property :title10Activation, type: :object do
                items do
                  property :title10ActivationDate, type: :array do
                    key :$ref, :DateRange
                  end
                  property :anticipatedSeparationDate, type: :array do
                    key :$ref, :DateRange
                  end
                end
              end
            end
          end
        end

        swagger_schema :UnemployabilityAttachments do
          key :required, %i[name attachmentId]

          property :name, type: :string
          property :confirmationCode, type: :string
          property :attachmentId, type: :string, enum:
            %w[
              L149
              L023
            ]
        end

        swagger_schema :VATreatmentFacility do
          key :required, %i[treatmentCenterName treatedDisabilityNames]

          property :treatmentCenterName,
                   type: :string,
                   maxLength: 100,
                   pattern: /^([a-zA-Z0-9\-'.#]([a-zA-Z0-9\-'.# ])?)+$/
          property :treatmentDateRange, type: :array do
            key :$ref, :DateRange
          end
          property :treatmentCenterAddress, type: :object do
            key :required, [:country]

            # See link for country enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L68-L285
            property :country, type: :string, example: 'USA'
            property :city,
                     type: :string,
                     maxLength: 30,
                     pattern: /^([-a-zA-Z0-9'.#]([-a-zA-Z0-9'.# ])?)+$/
            # See link for state enum
            # https://github.com/department-of-veterans-affairs/vets-json-schema/blob/76083e33f175fb00392e31f1f5f90654d05f1fd2/dist/21-526EZ-ALLCLAIMS-schema.json#L286-L353
            property :state, type: :string, example: 'OR'
          end
          property :treatedDisabilityNames,
                   type: :array,
                   minItems: 1,
                   maxItems: 100 do
            items type: :string
          end
        end
      end
    end
  end
end
