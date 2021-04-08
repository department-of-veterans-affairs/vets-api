# frozen_string_literal: true

require_relative 'communication_base'

module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attr_accessor :allowed
      attr_reader :id

      validates :allowed, inclusion: { in: [true, false], message: 'must be set' }

      def id=(val)
        @id = val&.to_i
      end
    end
  end
end
