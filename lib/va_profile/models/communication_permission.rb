# frozen_string_literal: true

require_relative 'communication_base'

module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attr_accessor :id, :allowed

      validates :allowed, inclusion: [true, false]
    end
  end
end
