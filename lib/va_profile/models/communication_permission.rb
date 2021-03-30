require_relative 'communication_base'

module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attr_accessor :id, :allowed

      validates :allowed, presence: true
    end
  end
end
