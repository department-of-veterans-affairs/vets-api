# frozen_string_literal: true

module Identity
  module Parsers
    module GCIdsHelper
      # @param edipi[String] An string representing the edipi id
      # @return [String] A string of 10 numerical digits representing the sanitized id
      def sanitize_edipi(edipi)
        return unless edipi.present? && edipi.is_a?(String)

        # Remove non-digit characters from input, and match the first contiguous 10 digits found
        edipi.match(/\d{10}/)&.to_s
      end

      # @param id [String] An string representing the id
      # @return [String] A string of any number of numerical digits representing the sanitized id
      def sanitize_id(id)
        return unless id.present? && id.is_a?(String)

        # Remove non-digit characters from input
        id.match(/\d+/)&.to_s
      end
    end
  end
end
