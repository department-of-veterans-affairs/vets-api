require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attr_accessor :id, :name, :description, :communication_permission

      validates :id, :communication_permission, presence: true
    end
  end
end
