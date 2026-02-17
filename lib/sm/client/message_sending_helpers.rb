# frozen_string_literal: true

module SM
  class Client < Common::Client::Base
    ##
    # Helper methods for message sending operations
    #
    module MessageSendingHelpers
      private

      def multipart_headers
        token_headers.merge('Content-Type' => 'multipart/form-data')
      end

      def build_message_response(json, poll_for_status, method_name)
        message = Message.new(json[:data].merge(json[:metadata]))
        build_lg_message_response(message, poll_for_status, method_name)
      end

      def build_lg_message_response(message, poll_for_status, method_name)
        log_oh_pilot_message(message, method_name)
        return poll_status(message) if poll_for_status

        message
      end

      ##
      # Look up the station_number for a given recipient_id using cached triage teams.
      # Returns 'unknown' if the lookup fails or no match is found.
      #
      # @param recipient_id [Integer, String, nil] the triage team id the message was sent to
      # @return [String] the station_number or 'unknown' if not found
      #
      def resolve_station_number(recipient_id)
        return 'unknown' if recipient_id.blank?

        cached_teams = get_triage_teams_station_numbers
        return 'unknown' if cached_teams.blank?

        matching_team = cached_teams.find { |team| team.triage_team_id == recipient_id }
        matching_team&.station_number || 'unknown'
      rescue => e
        Rails.logger.error("Error resolving station number: #{e.message}")
        'unknown'
      end

      def log_oh_pilot_message(message, method_name)
        return unless oh_pilot_user?

        log_message_to_rails("MHV SM OH Pilot User: #{method_name}", 'info', {
                               message_id: message&.id,
                               recipient_id: "***#{message&.recipient_id&.to_s&.last(6)}",
                               is_oh_message: message&.is_oh_message,
                               mhv_correlation_id: "****#{current_user&.mhv_correlation_id.to_s.last(6)}",
                               client_type: client_type_name
                             })
      end
    end
  end
end
