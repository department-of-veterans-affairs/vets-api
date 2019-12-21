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
            key :description, 'Intent to File ID from EVSS'
          end

          property :type do
            key :type, :string
            key :example, 'evss_intent_to_file_intent_to_files'
            key :description, 'Required by JSON API standard'
          end

          property :attributes do
            key :type, :object
            key :description, 'Required by JSON API standard'

            property :date_filed do
              key :type, :string
              key :format, 'datetime'
              key :example, '2014-07-28T19:53:45.810+00:00'
              key :description, 'Datetime intent to file was first called'
            end

            property :expiration_date do
              key :type, :string
              key :format, 'datetime'
              key :example, '2015-08-28T19:52:25.601+00:00'
              key :description, 'One year from initial intent to file Datetime'
            end

            property :type do
              key :type, :string
              key :example, 'compensation'
              key :description, 'Type of claim being submitted'
              key :enum, %w[
                compensation
                burial
                pension
              ]
            end

            property :status do
              key :type, :string
              key :example, 'active'
              key :description, 'Says if the Intent to File is Active or Expired'
            end
          end
        end
      end
    end
  end
end
