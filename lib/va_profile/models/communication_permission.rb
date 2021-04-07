# frozen_string_literal: true

require_relative 'communication_base'

module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attr_accessor :id, :allowed

      validates :allowed, inclusion: { in: [true, false], message: 'must be set' }
    end
  end
end
