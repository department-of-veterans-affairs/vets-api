# frozen_string_literal: true

require_relative 'communication_base'

module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attr_accessor :allowed, :sensitive
      attr_reader :id

      validates :allowed, inclusion: { in: [true, false], message: 'must be set' }
      # the sensitive indicator is only relevant for health appointment reminders
      validates :sensitive, allow_blank: true, inclusion: { in: [true, false] }

      def id=(val)
        @id = val&.to_i
      end
    end
  end
end
