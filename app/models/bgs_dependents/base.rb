# frozen_string_literal: true

module BGSDependents
  class Base < Common::Base
    include ActiveModel::Validations
    # Gets the person's address based on the lives with veteran flag
    #
    # @param dependents_application [Hash] the submitted form information
    # @param lives_with_vet [Boolean] does live with veteran indicator
    # @param alt_address [Hash] alternate address
    # @return [Hash] address information
    #
    def dependent_address(dependents_application:, lives_with_vet:, alt_address:)
      return dependents_application.dig('veteran_contact_information', 'veteran_address') if lives_with_vet

      alt_address
    end

    # Converts a string "00/00/0000" to standard iso8601 format
    #
    # @return [String] formatted date
    #
    def format_date(date)
      return nil if date.nil?

      Date.parse(date).to_time.iso8601
    end
  end
end
