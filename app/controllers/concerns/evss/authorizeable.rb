# frozen_string_literal: true

module EVSS
  module Authorizeable
    extend ActiveSupport::Concern

    def authorize_evss!
      unless EVSSPolicy.new(@current_user, :evss).access?
        raise Common::Exceptions::Forbidden.new(detail: error_detail, source: 'EVSS')
      end
    end

    private

    def error_detail
      "User does not have access to the requested resource due to missing values: #{missing_values}"
    end

    # Returns a comma-separated string of the user's blank attributes. `participant_id` is AKA `corp_id`.
    #
    # @return [String] Comma-separated string of the attribute names
    #
    def missing_values
      missing = []

      missing << 'corp_id' if @current_user.participant_id.blank?
      missing << 'edipi' if @current_user.edipi.blank?
      missing << 'ssn' if @current_user.ssn.blank?

      missing.join(', ')
    end
  end
end
