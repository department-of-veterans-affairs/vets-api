# frozen_string_literal: true

require './lib/common/exceptions/base_error'
require_relative 'serializable_error'

module ClaimsApi
  module V2
    module Common
      module Exceptions
        class ServiceError < ::Common::Exceptions::BaseError
          attr_writer :source

          def errors
            return @errors if @errors.present?

            Array(ClaimsApi::V2::Common::Exceptions::SerializableError.new(
                    i18n_data.merge(
                      source: "{'pointer': '/data/attributes/#{@source}'}",
                      detail: @detail,
                      title: @title
                    )
                  ))
          end
        end
      end
    end
  end
end
