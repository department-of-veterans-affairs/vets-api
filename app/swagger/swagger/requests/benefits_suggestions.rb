# frozen_string_literal: true

# ../vets-api/app/controllers/v0/concerns/swagger/requests/benefits_suggestions.rb
module Swagger
  module Requests
    class BenefitsSuggestions
      include Swagger::Blocks

      swagger_path '/v0/benefits_suggestions' do
        operation :post do
          key :summary, 'Suggests benefits based on a completed form'
          key :description,
              'Accepts a completed form ID and submitted data to suggest potentially relevant VA benefits or forms.'
          key :operationId, 'postBenefitsSuggestions'
          key :tags, [
            'benefits_forms' # Or a new tag like 'benefit_suggestions' if you add it to ApidocsController
          ]

          parameter do
            key :name, :params
            key :in, :body
            key :description, 'Completed form ID and submitted data'
            key :required, true
            schema do
              key :type, :object
              property :completed_form_id do
                key :type, :string
                key :description, 'ID of the completed form (e.g., "10-10EZ").'
                key :example, '10-10EZ'
              end
              property :submitted_data do
                key :type, :object
                key :description, 'Data from the completed form. Structure varies by form.'
                # Example for submitted_data (can be more detailed if there's a common structure)
                key :example,
                    { _meta: { relationship_to_veteran: 'spouse' },
                      veteranInfo: { vaCompensationType: 'highDisability' } }
              end
              key :required, [:completed_form_id]
            end
          end

          response 200 do
            key :description, 'Successfully retrieved benefit suggestions.'
            schema do
              key :type, :object
              property :suggestions do
                key :type, :array
                items do
                  key :type, :object
                  # Define properties of a single suggestion object
                  property :target_form_id do
                    key :type, :string
                    key :example, '10-10D'
                  end
                  property :rule_name do
                    key :type, :string
                    key :example, 'Spouse of Living P&T Vet'
                  end
                  property :eligible do
                    key :type, :boolean
                    key :example, true
                  end
                  property :reason do
                    key :type, :string
                  end
                  property :confidence do
                    key :type, :string
                    key :example, 'medium'
                  end
                  property :target_form_name do
                    key :type, :string
                    key :example, '10-10D'
                  end
                  property :target_form_description do
                    key :type, :string
                  end
                  property :notes do
                    key :type, :string
                    key :nullable, true
                  end
                  property :clarifying_questions do
                    key :type, :array
                    items do
                      key :type, :string
                    end
                    key :nullable, true
                    key :example, ['Is the Veteran deceased?']
                  end
                  # Add any other fields that your service returns in a suggestion
                end
              end
            end
          end

          response 400 do
            key :description, 'Bad Request (e.g., missing required parameters or invalid data structure).'
            schema do
              key :$ref, :Errors # Assuming a shared Errors schema is defined
            end
          end

          response 401 do
            key :description, 'Unauthorized.'
            # schema do
            #   key :$ref, :AuthenticationError # If you have a specific schema for this
            # end
          end

          # Potentially add 422 if you have validation errors with specific formats
          # response 422 do
          #   key :description, 'Unprocessable Entity (e.g., validation errors).'
          #   schema do
          #     key :$ref, :UnprocessableEntityError # Assuming a shared schema
          #   end
          # end
        end
      end
    end
  end
end
