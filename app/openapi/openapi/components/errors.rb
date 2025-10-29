# frozen_string_literal: true

module Openapi
  module Components
    class Errors
      ERRORS = { required: ['errors'],
                 properties: { errors: { type: 'array', items: { :$ref => '#/components/schemas/Error' } } } }.freeze
      ERROR =
        { required: %w[title detail code status],
          properties: { title: { type: 'string', example: 'Bad Request', description: 'error class name' },
                        detail: { type: 'string', example: 'Received a bad request response from the upstream server',
                                  description: 'possibly some additional info, or just the class name again' },
                        code: {
                          type: 'string',
                          example: 'EVSS400',
                          description: 'Sometimes just the http code again, sometimes something like ' \
                                       '"EVSS400", where the code can be found in config/locales/exceptions.en.yml'
                        },
                        source: { type: %w[string object], example: 'EVSS::DisabilityCompensationForm::Service',
                                  description: 'error source class' },
                        status: { type: 'string', example: '400', description: 'http status code' },
                        meta: { type: 'object', description: 'additional info, like a backtrace' } } }.freeze
    end
  end
end
