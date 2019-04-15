# frozen_string_literal: true

module ClaimsApi
  class Form526ModelSwagger
    include Swagger::Blocks

    swagger_schema :Form526 do
      key :required, %i[type attributes]
      key :description, '526 Claim Form submission with minimum required for auto establishment'
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
          key :description, ''

          property :servicePeriods do
            key :type, :array
            key :description, ''
            items do
              key :type, :object
              property :serviceBranch do
                key :type, :string
                key :example, 'Air Force'
                key :description, 'Branch of Service during period'
                key :enum, [
                    "Air Force",
                    "Air Force Reserve",
                    "Army",
                    "Army Reserve",
                    "Coast Guard",
                    "Coast Guard Reserve",
                    "Marine Corps",
                    "Marine Corps Reserve",
                    "Navy",
                    "Navy Reserve",
                    "NOAA"
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
        end

        property :disabilities do
          key :type, :object
          key :description, ''
          key :required, []
        end

        property :treatments do
          key :type, :object
          key :description, ''
          key :required, []
        end

        property :servicePay do
          key :type, :object
          key :description, ''
          key :required, []
        end

        property :directDeposit do
          key :type, :object
          key :description, ''
          key :required, []
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
