# frozen_string_literal: true

module HealthQuest
  module PatientGeneratedData
    class OptionsBuilder
      attr_reader :user, :filters

      def self.manufacture(user, filters)
        new(user, filters)
      end

      def initialize(user, filters)
        @user = user
        @filters = filters
      end

      def to_hash
        if appointment_id.present?
          { subject: appointment_reference }
        else
          { author: user.icn }
        end
      end

      def appointment_reference
        "#{Settings.hqva_mobile.url}/appointments/v1/patients/#{user.icn}/Appointment/#{appointment_id}"
      end

      def appointment_id
        @appointment_id ||= filters&.fetch(:appointment_id, nil)
      end
    end
  end
end
