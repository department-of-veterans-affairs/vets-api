# frozen_string_literal: true

module Mobile
  module V0
    module Exceptions
      class ValidationErrors < Common::Exceptions::ValidationErrors
        def errors
          @resource.errors.map do |message|
            Common::Exceptions::SerializableError.new(
              i18n_data.merge(
                detail: "#{message.path.first} #{message.text}"
              )
            )
          end
        end

        private

        def i18n_key
          'common.exceptions.MOBL_422_validation_error'
        end
      end
    end
  end
end
