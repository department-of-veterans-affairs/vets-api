# frozen_string_literal: true

module Swagger
  module Schemas
    class Errors
      include Swagger::Blocks

      swagger_schema :Errors do
        key :required, [:errors]

        property :errors do
          key :type, :array
          items do
            key :$ref, :Error
          end
        end
      end

      swagger_schema :Error do
        key :required, %i[title detail code status]
        property :title, type: :string, example: 'Bad Request', description: 'error class name'
        property :detail, type: :string, example: 'Received a bad request response from the upstream server',
                          description: 'possibly some additional info, or just the class name again'
        property :code, type: :string, example: 'EVSS400',
                        description: 'Sometiems just the http code again, sometimes something like "EVSS400", where" \
                        " the code can be found in config/locales/exceptions.en.yml'
        property :source, type: %i[string object], example: 'EVSS::DisabilityCompensationForm::Service',
                          description: 'error source class'
        property :status, type: :string, example: '400', description: 'http status code'
        property :meta, type: :object, description: 'additional info, like a backtrace'
      end
    end
  end
end
