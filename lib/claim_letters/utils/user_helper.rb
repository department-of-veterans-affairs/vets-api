# frozen_string_literal: true

module ClaimLetters
  module Utils
    module UserHelper
      def self.file_number(user)
        return local_file_number(user) if user.participant_id.blank?

        remote_file_number(user) || user.ssn
      end

      def self.local_file_number(user)
        user.file_number.presence || user.ssn
      end

      def self.remote_file_number(user)
        BGS::People::Request.new.find_person_by_participant_id(user:).file_number.presence
      end
    end
  end
end
