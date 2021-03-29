# frozen_string_literal: true

module AppealsApi::V1
  module Schemas
    class NoticeOfDisagreements
      include Swagger::Blocks

      swagger_component do
        schema :nodStatus do
          key :type, :string
          key :enum, AppealsApi::NodStatus::STATUSES
          key :example, 'submitted'
        end

        schema :nodCreateInput do
          key :required, %i[type attributes]
          key :description, 'Form 10182 with minimum required to establish.'

          property :data do
            key :type, :object
            property :type do
              key :type, :string
              key :example, 'noticeOfDisagreement'
              key :description, 'Required by JSON API standard'
            end

            property :attributes do
              key :type, :object
              key :description, 'Required by JSON API standard'
              key :required, %i[veteran boardReviewOption timezone socOptIn]

              property :veteran do
                key :type, :object
                key :description, 'Veteran Object being submitted in appeal'
                key :required, %i[homeless phone emailAddressText]

                property :homeless do
                  key :type, :boolean
                  key :example, false
                  key :description, 'Flag if Veteran is homeless'
                end

                property :address do
                  key :type, :object
                  key :description, 'Address of the Veteran - not required if Veteran is homeless. Cannot exceed 165
                                     characters when all fields are concatenated.'
                  key :required, %i[addressLine1 city countryName zipCode5]

                  property :addressLine1 do
                    key :type, :string
                    key :description, 'First line for address'
                  end

                  property :addressLine2 do
                    key :type, :string
                    key :description, 'Second line for address'
                  end

                  property :addressLine3 do
                    key :type, :string
                    key :description, 'Third line for address'
                  end

                  property :city do
                    key :type, :string
                    key :description, 'City of residence'
                  end

                  property :stateCode do
                    key :type, :string
                    key :description, 'State of residence in 2-character format'
                    key :example, 'UT'
                  end

                  property :zipCode5 do
                    key :type, :string
                    key :description, '5-digit zipcode. Use "00000" if Veteran is outside the United States'
                    key :example, '20001'
                    key :maxLength, 5
                    key :minLength, 5
                  end

                  property :countryName do
                    key :type, :string
                    key :description, 'Country of residence'
                  end

                  property :internationalPostalCode do
                    key :type, :string
                    key :description, 'Use if residence outside of the United States'
                  end
                end

                property :phone do
                  key :type, :object
                  key :description, 'The phone number of the veteran. Cannot exceed 20 characters when
                                     all fields are concatenated.'
                  key :required, %i[areaCode phoneNumber]

                  property :countryCode do
                    key :type, :string
                    key :minLength, 1
                    key :maxLength, 3
                  end

                  property :areaCode do
                    key :type, :string
                    key :minLength, 1
                    key :maxLength, 4
                  end

                  property :phoneNumber do
                    key :type, :string
                    key :minLength, 1
                    key :maxLength, 14
                  end

                  property :phoneNumberExt do
                    key :type, :string
                    key :minLength, 1
                    key :maxLength, 10
                  end
                end

                property :emailAddressText do
                  key :type, :string
                  key :format, :email
                  key :description, 'Email of the Veteran'
                  key :maxLength, 120
                  key :minLength, 5
                end
              end

              property :boardReviewOption do
                key :type, :string
                key :example, 'evidence_submission'
                key :description, 'Type of Board Review NOD being requested'
              end

              property :timezone do
                key :type, :string
                key :example, 'America/Chicago'
                key :description, 'Timezone of Veteran'
              end
              property :socOptIn do
                key :type, :boolean
                key :description, 'Indicates whether or not any contestable issues listed on the form are being
                                   withdrawn from the legacy appeals process'
              end
            end
          end

          property :included do
            key :type, :array
            key :minItems, 1
            key :maxItems, 100

            items do
              key :$ref, :contestableIssue
            end
          end
        end

        schema :nodCreateResponse do
          key :description, 'Successful response of a 10182 form submission'
          key :type, :object

          property :data do
            property :id do
              key :type, :string
              key :description, 'Unique ID of created NOD'
              key :example, '97751cb6-d06d-4179-87f6-75e3fc9d875c'
            end

            property :type do
              key :type, :string
              key :description, 'Name of record class'
              key :example, 'noticeOfDisagreement'
            end

            property :attributes do
              key :type, :object

              property :status do
                key :type, :string
                key :description, 'Status of NOD'
                key :example, 'pending'
              end

              property :createdAt do
                key :type, :string
                key :description, 'Created timestamp of the NOD'
                key :example, '2020-12-16T19:52:23.909Z'
              end

              property :updatedAt do
                key :type, :string
                key :description, 'Updated timestamp of the NOD'
                key :example, '2020-12-16T19:52:23.909Z'
              end
            end

            property :formData do
              key :type, :object

              property :data do
                key :type, :object

                property :type do
                  key :type, :string
                  key :example, 'noticeOfDisagreement'
                  key :description, 'The data type submitted'
                end

                property :attributes do
                  key :type, :object

                  property :veteran do
                    key :type, :object

                    property :homeless do
                      key :type, :boolean
                      key :example, false
                      key :description, 'Value of submitted homeless key'
                    end

                    property :address do
                      key :type, :object
                      key :description, 'Value of submitted address if not homeless'
                    end

                    property :phone do
                      key :type, :object
                      key :description, 'Value of submitted phone number'
                    end

                    property :emailAddressText do
                      key :type, :string
                      key :description, 'Value of submitted email'
                    end

                    property :representativesName do
                      key :type, :string
                      key :example, 'Mr. Wiggles'
                      key :description, 'The name of the representative for the NOD submission'
                      key :maxLength, 120
                    end
                  end

                  property :boardReviewOption do
                    key :type, :string
                    key :example, 'hearing'
                    key :description, 'The option selected for the NOD submission'
                  end

                  property :hearingTypePreference do
                    key :type, :string
                    key :example, 'video_conference'
                    key :description, 'The type of hearing selected'
                  end

                  property :timezone do
                    key :type, :string
                    key :example, 'America/Chicago'
                    key :description, 'The timezone selected for the NOD submission'
                  end

                  property :socOptIn do
                    key :type, :boolean
                    key :description, 'Indicates whether or not any contestable issues listed on the form are being
                                       withdrawn from the legacy appeals process'
                  end
                end
              end
            end
          end

          property :included do
            key :type, :array
            items do
              key :$ref, :contestableIssue
            end
          end
        end

        schema :errorModel do
          key :description, 'Errors with some details for the given request'

          property :status do
            key :type, :integer
            key :format, :int32
            key :example, '422'
            key :description, 'Standard HTTP Status returned with Error'
          end

          property :detail do
            key :type, :string
            key :example, 'invalidType is not an available option'
            key :description, 'A more detailed message about why an error occurred'
          end

          property :code do
            key :type, :string
            key :example, '151'
            key :description, 'Internal status code for error referencing'
          end

          property :title do
            key :type, :string
            key :example, 'Invalid option'
            key :description, 'The generic title of the error'
          end

          property :source do
            key :type, :object
            key :description, 'Location of JSON error within the schema.'

            property :pointer do
              key :type, :string
              key :example, '/data/type'
              key :description, 'Required by JSON API standard'
            end
          end

          property :meta do
            key :type, :object

            property :available_options do
              key :type, :array
              key :description, 'Array of allowed options for the enum value returned by the error'

              items do
                key :type, :string
                key :example, 'noticeOfDisagreement'
                key :description, 'Allowed options for the value of the property'
              end
            end

            property :missing_fields do
              key :type, :array
              key :description, 'An Array of missing required fields from the schema.'

              items do
                key :type, :string
                key :example, 'socOptIn'
                key :description, 'The name of the missing required field from the schema.'
              end
            end
          end
        end

        schema :contestableIssue do
          key :description, 'A contestable issue'
          key :type, :object

          property :type do
            key :type, :string
            key :example, 'contestableIssue'
            key :description, 'The type of data included'
          end

          property :attributes do
            key :type, :object

            property :issue do
              key :type, :string
              key :example, 'tinnitus'
              key :example, 'The type of issue being contested'
              key :maxLength, 255
            end

            property :decisionDate do
              key :type, :string
              key :example, '1900-01-01'
              key :example, 'The decision date for the contested issue'
              key :maxLength, 10
            end
          end
        end
      end
    end
  end
end
