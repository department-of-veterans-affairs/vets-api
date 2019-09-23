# frozen_string_literal: true

module ClaimsApi
  class Form526ModelSwagger
    include Swagger::Blocks

    swagger_schema :Form526Input do
      key :required, %i[type attributes]
      key :description, '526 Claim Form submission with minimum required for auto establishment. Note - Until a claim is established in VA systems, values may show null'
      property :type do
        key :type, :string
        key :example, 'form/526'
        key :description, 'Required by JSON API standard'
      end

      property :attributes do
        key :type, :object
        key :description, 'Required by JSON API standard'
        req = %i[veteran serviceInformation disabilities claimantCertification standardClaim applicationExpirationDate]
        key :required, req

        property :veteran do
          key :type, :object
          key :description, 'Veteran Object being submitted in Claim'
          key :required, %i[currentlyVAEmployee currentMailingAddress]

          property :currentlyVAEmployee do
            key :type, :boolean
            key :example, false
            key :description, 'Flag if Veteran is VA Employee'
          end

          property :currentMailingAddress do
            key :type, :object
            key :description, 'Current Mailing Address Object being submitted'
            key :required, %i[
              addressLine1
              city
              state
              country
              zipFirstFive
              type
            ]

            property :addressLine1 do
              key :type, :string
              key :example, '1234 Couch Street'
              key :description, 'Address Veteran resides in'
            end

            property :addressLine2 do
              key :type, :string
              key :example, 'Apt. 22'
              key :description, 'Additional Address Information Veteran resides in'
            end

            property :city do
              key :type, :string
              key :example, 'Portland'
              key :description, 'City Veteran resides in'
            end

            property :country do
              key :type, :string
              key :example, 'USA'
              key :description, 'Country Veteran resides in'
            end

            property :zipFirstFive do
              key :type, :string
              key :example, '12345'
              key :description, 'Zipcode (First 5 digits) Veteran resides in'
            end

            property :zipLastFour do
              key :type, :string
              key :example, '6789'
              key :description, 'Zipcode (Last 4 digits) Veteran resides in'
            end

            property :type do
              key :type, :string
              key :example, 'DOMESTIC'
              key :description, 'Type of residence Veteran resides in'
            end

            property :state do
              key :type, :string
              key :example, 'OR'
              key :description, 'State Veteran resides in'
            end
          end

          property :changeOfAddress do
            key :type, :object
            key :description, 'A Change of Address Object being submitted'

            property :beginningDate do
              key :type, :string
              key :format, 'date'
              key :example, '2018-06-04'
              key :description, 'Date in YYYY-MM-DD the Veteran changed address'
            end

            property :addressChangeType do
              key :type, :string
              key :example, 'PERMANENT'
              key :description, 'Temporary or Permanent change of address'
            end

            property :addressLine1 do
              key :type, :string
              key :example, '1234 Couch Stree'
              key :description, 'New Address Veteran resides in'
            end

            property :addressLine2 do
              key :type, :string
              key :example, 'Apt. 22'
              key :description, 'New Additional Address Information Veteran resides in'
            end

            property :city do
              key :type, :string
              key :example, 'Portland'
              key :description, 'New City Veteran resides in'
            end

            property :country do
              key :type, :string
              key :example, 'USA'
              key :description, 'New Country Veteran resides in'
            end

            property :zipFirstFive do
              key :type, :string
              key :example, '12345'
              key :description, 'New Zipcode (First 5 digits) Veteran resides in'
            end

            property :zipLastFour do
              key :type, :string
              key :example, '6789'
              key :description, 'New Zipcode (Last 4 digits) Veteran resides in'
            end

            property :type do
              key :type, :string
              key :example, 'DOMESTIC'
              key :description, 'New Type of residence Veteran resides in'
            end

            property :state do
              key :type, :string
              key :example, 'OR'
              key :description, 'New State Veteran resides in'
            end
          end

          property :homelessness do
            key :type, :object
            key :description, 'Object describing Veteran Homelessness if applicable'

            property :pointOfContact do
              key :type, :object
              key :description, 'Object describing Homeless Veteran Point of Contact'

              property :pointOfContactName do
                key :type, :string
                key :example, 'Jane Doe'
                key :description, 'Point of contact in direct contact with Veteran'
              end

              property :primaryPhone do
                key :type, :object
                key :description, 'Phone Number Object for Point of Contact'

                property :areaCode do
                  key :type, :string
                  key :example, '123'
                  key :description, 'Area code of Point of Contact'
                end

                property :phoneNumber do
                  key :type, :string
                  key :example, '1231234'
                  key :description, 'Primary phone of Point of Contact'
                end
              end
            end

            property :currentlyHomeless do
              key :type, :object
              key :description, ''
              key :required, []

              property :homelessSituationType do
                key :type, :string
                key :example, 'FLEEING_CURRENT_RESIDENCE'
                key :description, 'Current state of the veteran\'s homelessness'
                key :enum, %w[
                  FLEEING_CURRENT_RESIDENCE
                  LIVING_IN_A_HOMELESS_SHELTER
                  NOT_CURRENTLY_IN_A_SHELTERED_ENVIRONMENT
                  STAYING_WITH_ANOTHER_PERSON
                  OTHER
                ]
              end

              property :otherLivingSituation do
                key :type, :string
                key :example, 'other living situation'
                key :description, 'List any other living scenarios'
              end
            end
          end
        end

        property :serviceInformation do
          key :required, [:servicePeriods]
          key :type, :object
          key :description, 'Overview of Veteran\'s service history'

          property :servicePeriods do
            key :type, :array
            key :description, 'Identifies the Service dates and Branch the Veteran served in.'
            items do
              key :type, :object
              key :required, %i[
                serviceBranch
                activeDutyBeginDate
                activeDutyEndDate
              ]

              property :serviceBranch do
                key :type, :string
                key :example, 'Air Force'
                key :description, 'Branch of Service during period'
                key :enum, [
                  'Air Force',
                  'Air Force Reserve',
                  'Army',
                  'Army Reserve',
                  'Coast Guard',
                  'Coast Guard Reserve',
                  'Marine Corps',
                  'Marine Corps Reserve',
                  'Navy',
                  'Navy Reserve',
                  'NOAA'
                ]
              end

              property :activeDutyBeginDate do
                key :type, :string
                key :format, :date
                key :example, '1980-02-05'
                key :description, 'Date Started Active Duty'
              end

              property :activeDutyEndDate do
                key :type, :string
                key :format, :date
                key :example, '1990-01-02'
                key :description, 'Date Completed Active Duty'
              end
            end
          end

          property :confinements do
            key :type, :array
            key :description, 'Identifies if the Veteran was confined or imprisoned at any point'
            items do
              key :type, :object

              property :confinementBeginDate do
                key :type, :string
                key :format, :date
                key :example, '1987-02-01'
                key :description, 'Date Began Confinement'
              end

              property :confinementEndDate do
                key :type, :string
                key :format, :date
                key :example, '1987-02-01'
                key :description, 'Date Ended Confinement'
              end
            end
          end

          property :reservesNationalGuardService do
            key :type, :object
            key :description, 'Overview of Veteran\'s Reserve History'

            property :title10Activation do
              key :type, :object
              key :description, 'Dates of when Reserve Veteran was Activated'

              property :anticipatedSeparationDate do
                key :type, :string
                key :format, 'date'
                key :example, '2020-01-01'
                key :description, 'Date Seperation will occur'
              end

              property :title10ActivationDate do
                key :type, :string
                key :input, 'date'
                key :example, '1999-03-04'
                key :description, 'Date Title 10 Activates'
              end
            end

            property :obligationTermOfServiceFromDate do
              key :type, :string
              key :input, 'date'
              key :example, '2000-01-04'
              key :description, 'Date Service Obligation Began'
            end

            property :obligationTermOfServiceToDate do
              key :type, :string
              key :input, 'date'
              key :example, '2004-01-04'
              key :description, 'Date Service Obligation Ended'
            end

            property :unitName do
              key :type, :string
              key :example, 'Seal Team Six'
              key :description, 'Official Unit Designation'
            end

            property :unitPhone do
              key :type, :object
              key :description, 'Phone number Object for Vetern\'s old unit'

              property :areaCode do
                key :type, :string
                key :example, '123'
                key :description, 'Area code of Unit'
              end

              property :phoneNumber do
                key :type, :string
                key :example, '1231234'
                key :description, 'Primary phone of Unit'
              end
            end

            property :receivingInactiveDutyTrainingPay do
              key :type, :boolean
              key :example, true
              key :description, 'Do they receive Inactive Duty Training Pay'
            end
          end

          property :alternateNames do
            key :type, :array
            key :description, 'Names Veteran has legally used in the past'
            items do
              key :type, :object

              property :firstName do
                key :type, :string
                key :example, 'Jack'
                key :description, 'Alternate First Name'
              end

              property :middleName do
                key :type, :string
                key :example, 'Clint'
                key :description, 'Alternate Middle Name'
              end

              property :lastName do
                key :type, :string
                key :example, 'Bauer'
                key :description, 'Alternate Last Name'
              end
            end
          end
        end

        property :disabilities do
          key :type, :array
          key :description, 'Identifies the Service Disability information of the Veteran'

          items do
            key :type, :object
            key :required, %i[
              name
              disabilityActionType
            ]

            property :ratedDisabilityId do
              key :type, :string
              key :description, 'The Type of Disability'
              key :example, '1100583'
            end

            property :diagnosticCode do
              key :type, :integer
              key :description, 'Specific Diagnostic Code'
              key :example, 9999
            end

            property :disabilityActionType do
              key :type, :string
              key :description, 'The status of the current disability.'
              key :example, 'NEW'
            end

            property :name do
              key :type, :string
              key :description, 'What the Disability is called.'
              key :example, 'PTSD (post traumatic stress disorder)'
            end

            property :secondaryDisabilities do
              key :type, :array
              key :description, 'Identifies the Secondary Service Disability information of the Veteran'

              items do
                key :type, :object
                key :required, %i[
                  name
                  disabilityActionType
                  serviceRelevance
                ]

                property :name do
                  key :type, :string
                  key :description, 'What the Disability is called.'
                  key :example, 'PTSD personal trauma'
                end

                property :disabilityActionType do
                  key :type, :string
                  key :description, 'The status of the secondary disability.'
                  key :example, 'SECONDARY'
                end

                property :serviceRelevance do
                  key :type, :string
                  key :description, 'How the veteran got the disability.'
                  key :example, 'Caused by a service-connected disability\\nLengthy description'
                end
              end
            end
          end
        end

        property :treatments do
          key :type, :array
          key :description, 'Identifies the Service Treatment information of the Veteran'

          items do
            key :type, :object

            property :startDate do
              key :type, :date
              key :description, 'Date Veteran started treatment'
              key :example, '2018-03-02'
            end

            property :endDate do
              key :type, :date
              key :description, 'Date Veteran ended treatment'
              key :example, '2018-03-03'
            end

            property :treatedDisabilityNames do
              key :type, :array
              key :description, 'Identifies the Service Treatment nomenclature of the Veteran'

              items do
                key :type, :string
                key :description, 'Name of Disabilities Veteran was Treated for'
                key :example, 'PTSD (post traumatic stress disorder)'
              end
            end

            property :center do
              key :type, :object
              key :description, 'Location of Veteran Treatment'

              property :name do
                key :type, :string
                key :description, 'Name of facility Veteran was treated in'
                key :example, 'Private Facility 2'
              end

              property :country do
                key :type, :string
                key :description, 'Country Veteran was treated in'
                key :example, 'USA'
              end
            end
          end
        end

        property :servicePay do
          key :type, :object
          key :description, 'Details about Veteran receiving Service Pay from DoD'

          property :waiveVABenefitsToRetainTrainingPay do
            key :type, :boolean
            key :description, 'Is Veteran Waiving benefits to retain training pay'
            key :example, true
          end

          property :waiveVABenefitsToRetainRetiredPay do
            key :type, :boolean
            key :description, 'Is Veteran Waiving benefits to retain Retiree pay'
            key :example, true
          end

          property :militaryRetiredPay do
            key :type, :object
            key :description, 'Retirement Pay information from Military Service'

            property :receiving do
              key :type, :boolean
              key :description, 'Is Veteran getting Retiree pay'
              key :example, true
            end

            property :payment do
              key :type, :object
              key :description, 'Part of DoD paying Retirement Benefits'

              property :serviceBranch do
                key :type, :string
                key :description, 'Branch of Service making payments'
                key :example, 'Air Force'
                key :enum, [
                  'Air Force',
                  'Air Force Reserve',
                  'Army',
                  'Army Reserve',
                  'Coast Guard',
                  'Coast Guard Reserve',
                  'Marine Corps',
                  'Marine Corps Reserve',
                  'Navy',
                  'Navy Reserve',
                  'NOAA'
                ]
              end
            end
          end
        end

        property :directDeposit do
          key :type, :object
          key :description, 'Financial Direct Deposit information for Veteran'
          key :required, %w[
            accountType
            accountNumber
            routingNumber
          ]

          property :accountType do
            key :type, :string
            key :description, 'Veteran Account Type'
            key :example, 'CHECKING'
            key :enum, %w[CHECKING SAVINGS]
          end

          property :accountNumber do
            key :type, :string
            key :description, 'Veteran Bank Account Number'
            key :example, '123123123123'
          end

          property :routingNumber do
            key :type, :string
            key :description, 'Veteran Bank Routing Number'
            key :example, '123123123'
          end

          property :bankName do
            key :type, :string
            key :description, 'Veteran Bank Name'
            key :example, 'Some Bank'
          end
        end

        property :claimantCertification do
          key :type, :boolean
          key :example, true
          key :description, 'Determines if person submitting the claim is certified to do so.'
        end

        property :standardClaim do
          key :type, :boolean
          key :example, false
          key :description, 'Determines if claim is considered a Standard Claim.'
        end

        property :applicationExpirationDate do
          key :type, :string
          key :format, 'date-time'
          key :example, '2018-08-28T19:53:45+00:00'
          key :description, 'Time stamp of when claim expires in one year after submission.'
        end
      end
    end
  end
end
