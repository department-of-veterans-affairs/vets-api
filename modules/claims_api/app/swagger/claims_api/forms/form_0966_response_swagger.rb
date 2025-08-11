# frozen_string_literal: true

module ClaimsApi
  module Forms
    class Form0966ResponseSwagger
      include Swagger::Blocks

      swagger_component do
        schema :Form0966Output do
          key :required, %i[type attributes]
          key :description, '526 Claim Form submission with minimum required for auto establishment'

          property :id do
            key :type, :string
            key :example, '1056'
            key :description, 'Intent to File ID from Lighthouse'
          end

          property :type do
            key :type, :string
            key :example, 'intent_to_file'
            key :description, 'Required by JSON API standard'
          end

          property :attributes do
            key :type, :array
            items do
              key :type, :object
              key :description, 'Required by JSON API standard'

              property :received_date do
                key :type, :string
                key :format, 'datetime'
                key :example, '2014-07-28T19:53:45.810+00:00'
                key :description, I18n.t('claims_api.field_descriptions.received_date')
              end

              property :expiration_date do
                key :type, :string
                key :format, 'datetime'
                key :example, '2015-08-28T19:52:25.601+00:00'
                key :description, 'One year from initial intent to file Datetime'
                key :description, I18n.t('claims_api.field_descriptions.expiration_date')
              end

              property :type do
                key :type, :string
                key :example, 'compensation'
                key :description, I18n.t('claims_api.field_descriptions.type')
                key :enum, %w[
                  compensation
                  burial
                  pension
                ]
              end

              property :status do
                key :type, :string
                key :example, 'active'
                key :enum, %w[active inactive]
                key :description, I18n.t('claims_api.field_descriptions.status')
              end

              property :intent_to_file_id do
                key :type, :integer
                key :example, 234
                key :description, I18n.t('claims_api.field_descriptions.intent_to_file_id')
              end

              property :participant_claimant_id do
                key :type, :integer
                key :example, 234
                key :description, I18n.t('claims_api.field_descriptions.participant_claimant_id')
              end
              property :participant_vet_id do
                key :type, :integer
                key :example, 234
                key :description, I18n.t('claims_api.field_descriptions.participant_vet_id')
              end
              property :status_date do
                key :type, :string
                key :format, 'datetime'
                key :example, '2015-08-28T19:52:25.601+00:00'
                key :description, I18n.t('claims_api.field_descriptions.status_date')
              end
            end
          end
        end
      end
    end
  end
end
