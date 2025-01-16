# frozen_string_literal: true

module Mobile
  module V0
    module Exceptions
      class ValidationErrors < Common::Exceptions::ValidationErrors
        def errors
          @resource.errors.details.map do |k, v|
            Common::Exceptions::SerializableError.new(
              i18n_data.merge(
                detail: "#{k} #{v.first}"
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
