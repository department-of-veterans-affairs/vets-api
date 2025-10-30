# frozen_string_literal: true

require_relative '../section'

module Pensions
  module PdfFill
    # Section VII: Prior Marital History
    class Section7 < Section
      # Section configuration hash
      KEY = {}.freeze

      ##
      # Expand the form data for prior marital history.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      # Note: This method modifies `form_data`
      #
      def expand(form_data)
        expand_prior_marital_history(form_data)
      end

      ##
      # Expand prior marital history data.
      #
      # @param form_data [Hash] The form data hash.
      #
      # @return [void]
      #
      #  Note: This method modifies `form_data`
      #
      def expand_prior_marital_history(form_data)
        form_data['marriages'] = build_marital_history(form_data['marriages'], 'VETERAN')
        form_data['spouseMarriages'] = build_marital_history(form_data['spouseMarriages'], 'SPOUSE')
        if form_data['marriages']&.any?
          form_data['additionalMarriages'] = to_radio_yes_no(form_data['marriages'].length.to_i > 3)
        end
        if form_data['spouseMarriages']&.any?
          form_data['additionalSpouseMarriages'] = to_radio_yes_no(form_data['spouseMarriages'].length.to_i > 2)
        end
      end

      ##
      # Build marital history entries.
      #
      # @param marriages [Array<Hash>] The array of marriage entries.
      # @param marriage_for [String] Indicates whether the marriages are for 'VETERAN' or 'SPOUSE'.
      #
      # @return [Array<Hash>] The processed array of marriage entries.
      #
      def build_marital_history(marriages, marriage_for = 'VETERAN')
        return [] unless marriages.present? && %w[VETERAN SPOUSE].include?(marriage_for)

        marriages.map do |marriage|
          reason_for_separation = marriage['reasonForSeparation'].to_s
          marriage_date_range = {
            'from' => marriage['dateOfMarriage'],
            'to' => marriage['dateOfSeparation']
          }
          marriage.merge!({ 'spouseFullNameOverflow' => marriage['spouseFullName']&.values&.join(' '),
                            'dateOfMarriage' => split_date(marriage['dateOfMarriage']),
                            'dateOfSeparation' => split_date(marriage['dateOfSeparation']),
                            'dateRangeOfMarriageOverflow' => build_date_range_string(marriage_date_range),
                            'reasonForSeparation' => Constants::REASONS_FOR_SEPARATION[reason_for_separation],
                            'reasonForSeparationOverflow' => reason_for_separation.humanize })
          marriage['spouseFullName']['middle'] = marriage['spouseFullName']['middle']&.first
          marriage
        end
      end
    end
  end
end
