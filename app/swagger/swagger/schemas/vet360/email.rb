# frozen_string_literal: true

require 'va_profile/models/email'

module Swagger
  module Schemas
    module Vet360
      class Email
        include Swagger::Blocks

        swagger_schema :PostVet360Email do
          key :required, %i[email_address]
          property :email_address,
                   type: :string,
                   example: 'john@example.com',
                   minLength: 6,
                   maxLength: 255,
                   pattern: VAProfile::Models::Email::VALID_EMAIL_REGEX.inspect
          property :confirmation_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: nil,
                   description: "Confirmation date should only be provided if the email is 'confirmed' by the user"
        end

        swagger_schema :PutVet360Email do
          key :required, %i[email_address id]
          property :id, type: :integer, example: 1
          property :email_address,
                   type: :string,
                   example: 'john@example.com',
                   minLength: 6,
                   maxLength: 255,
                   pattern: VAProfile::Models::Email::VALID_EMAIL_REGEX.inspect
          property :confirmation_date,
                   type: %i[string null],
                   format: 'date-time',
                   example: '2025-01-01T00:00:00Z',
                   description: "Confirmation date should only be provided if the email is 'confirmed' by the user"
        end
      end
    end
  end
end
