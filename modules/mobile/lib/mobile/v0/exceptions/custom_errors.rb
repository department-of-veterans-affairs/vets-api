# frozen_string_literal: true

require 'common/exceptions/base_error'

module Mobile
  module V0
    module Exceptions
      class CustomErrors < Common::Exceptions::BaseError
        attr_reader :title, :body, :source, :telephone, :refreshable

        def initialize(title:, body:, source:, telephone:, refreshable:)
          @title = title
          @body = body
          @source = source
          @telephone = telephone
          @refreshable = refreshable
          super
        end

        def errors
          [
            {
              title: @title,
              body: @body,
              status: i18n_data[:status],
              source: @source,
              telephone: @telephone,
              refreshable: @refreshable
            }
          ]
        end

        private

        def i18n_key
          'common.exceptions.MOBL_418_custom_error'
        end
      end
    end
  end
end
