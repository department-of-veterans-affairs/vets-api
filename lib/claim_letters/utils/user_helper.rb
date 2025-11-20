# frozen_string_literal: true

module ClaimLetters
  module Utils
    module UserHelper
      def self.file_number(user)
        return local_file_number(user) if safe_get(user, :participant_id).blank?

        remote_file_number(user) || safe_get(user, :ssn)
      end

      def self.local_file_number(user)
        safe_get(user, :file_number).presence || safe_get(user, :ssn)
      end

      def self.remote_file_number(user)
        BGS::People::Request.new.find_person_by_participant_id(user:).file_number.presence
      rescue => e
        Rails.logger.warn "Failed to fetch remote file number: #{e.message}"
        nil
      end

      def self.safe_get(user, attribute)
        case user
        when Hash
          user[attribute] || user[attribute.to_s] || user[attribute.to_sym]
        when nil
          nil
        else
          user.public_send(attribute) if user.respond_to?(attribute)
        end
      end
    end
  end
end
