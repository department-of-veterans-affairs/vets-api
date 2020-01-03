# frozen_string_literal: true

module ClaimsApi
  module Forms
    class Form2122ResponseSwagger
      include Swagger::Blocks

      swagger_component do
        schema :Form2122Input do
          key :required, %i[type attributes]
          key :description, '2122 Power of Attorney Form submission'
          property :data do
            key :type, :object
            property :type do
              key :type, :string
              key :example, 'form/21-22'
              key :description, 'Required by JSON API standard'
            end

            property :attributes do
              key :type, :object
              key :description, 'Required by JSON API standard'
              key :required, %i[poa_code poa_first_name poa_last_name]

              property :poaCode do
                key :type, :string
                key :example, 'A01'
                key :description, 'Power of Attorney Code being submitted for Veteran'
              end

              property :poaFirstName do
                key :type, :string
                key :example, 'Bob'
                key :description, 'First Name of person in organization being associated with Power of Attorney'
              end

              property :poaLastName do
                key :type, :string
                key :example, 'Jones'
                key :description, 'Last Name of person in organization being associated with Power of Attorney'
              end
            end
          end
        end

        schema :Form2122Output do
          key :required, %i[type attributes]
          key :description, '2122 Power of Attorney Form response'

          property :id do
            key :type, :string
            key :example, '6e47701b-802b-4520-8a41-9af2117a20bd'
            key :description, 'Power of Attorney Submission UUID'
          end

          property :type do
            key :type, :string
            key :example, 'evss_power_of_attorney'
            key :description, 'Required by JSON API standard'
          end

          property :attributes do
            key :type, :object
            key :description, 'Required by JSON API standard'

            property :relationship_type do
              key :type, :string
              key :example, ''
              key :description, 'Type of relationships'
            end

            property :date_request_accepted do
              key :type, :string
              key :format, 'date'
              key :example, '2014-07-28'
              key :description, 'Date request was first accepted'
            end

            property :status do
              key :type, :string
              key :example, 'submitted'
              key :description, 'Says if the power of attorney is pending, updated or errored'
              key :enum, %w[
                pending
                updated
                errored
              ]
            end

            property :representative do
              key :type, :object
              key :description, 'Information about VSO, Attorney or Claims Agents'

              property :poa_code do
                key :type, :string
                key :example, 'A01'
                key :description, 'Power of Attorney Code submitted for Veteran'
              end

              property :poa_first_name do
                key :type, :string
                key :example, 'A01'
                key :description, 'Power of Attorney representative first name submitted for Veteran'
              end

              property :poa_last_name do
                key :type, :string
                key :example, 'A01'
                key :description, 'Power of Attorney representative last name submitted for Veteran'
              end

              property :current_poa do
                key :type, :string
                key :example, 'A01'
                key :description, 'Current or Previous Power of Attorney Code submitted for Veteran'
              end

              property :participant_id do
                key :type, :string
                key :example, '987654'
                key :description, 'Participant ID for veteran representative'
              end
            end

            property :veteran do
              key :type, :object
              key :description, 'Information about Veteran'

              property :participant_id do
                key :type, :string
                key :example, '14567'
                key :description, 'Participant ID for veteran'
              end
            end
          end
        end
      end
    end
  end
end
