# frozen_string_literal: true

##
# Shared concern for handling pension award logic across form profiles
# Provides methods to determine if a veteran is in receipt of pension based on current awards data
module PensionAwardHelper
  extend ActiveSupport::Concern

  # Constants representing pension receipt status
  PENSION_STATUS = {
    receiving: 1,
    not_receiving: 0,
    error: -1
  }.freeze

  # @return [Integer] 1 if user is in receipt of pension, 0 if not, -1 if request fails
  # Needed for FE to differentiate between 200 response and error
  def is_in_receipt_of_pension # rubocop:disable Naming/PredicatePrefix
    case awards_pension[:is_in_receipt_of_pension]
    when true
      PENSION_STATUS[:receiving]
    when false
      PENSION_STATUS[:not_receiving]
    else
      PENSION_STATUS[:error]
    end
  end

  # @return [Integer] the net worth limit for pension, default is 163,699 as of 2026
  # Default will be cached in future enhancement
  def net_worth_limit
    awards_pension[:net_worth_limit] || 163_699
  end

  # @return [Hash] the awards pension data from BID service or an empty hash if the request fails
  def awards_pension
    @awards_pension ||= begin
      response = pension_award_service.get_current_awards
      current_awards_data = response.try(:body)

      if current_awards_data.present?
        award_lines = extract_award_lines(current_awards_data)
        latest_award_line = find_latest_effective_award_line(award_lines)
        is_receiving_pension = latest_award_line&.dig('award_line_type') == 'IP'

        { is_in_receipt_of_pension: is_receiving_pension }
      else
        {}
      end
    rescue => e
      track_pension_award_error(e)
      {}
    end
  end

  private

  ##
  # Extracts award lines from the current awards response
  #
  # @param current_awards_data [Hash] The response body from get_current_awards
  # @return [Array] Array of award lines
  def extract_award_lines(current_awards_data)
    current_awards_data.dig('award', 'award_event_list', 'award_events')&.flat_map do |award_event|
      award_event.dig('award_line_list', 'award_lines') || []
    end || []
  end

  ##
  # Finds the latest effective award line that is prior to today
  #
  # @param award_lines [Array] Array of award line hashes
  # @return [Hash, nil] The latest effective award line or nil if none found
  def find_latest_effective_award_line(award_lines)
    return nil if award_lines.blank?

    today = Date.current

    # Filter lines with effective dates prior to today
    valid_lines = award_lines.filter_map do |line|
      effective_date = DateTime.parse(line['effective_date']).to_date
      line if effective_date < today
    end

    # Return the line with the latest effective date
    valid_lines.max_by { |line| DateTime.parse(line['effective_date']).to_date }
  end

  ##
  # Abstract method that must be implemented by including classes
  # Handles error tracking specific to each form profile's monitoring approach
  #
  # @param error [Exception] The error that occurred during pension award retrieval
  def track_pension_award_error(error)
    raise NotImplementedError, 'Including class must implement #track_pension_award_error'
  end

  ##
  # Abstract method that must be implemented by including classes
  # Returns the pension award service instance
  #
  # @return [BID::Awards::Service] Service for retrieving pension award data
  def pension_award_service
    raise NotImplementedError, 'Including class must implement #pension_award_service'
  end
end
