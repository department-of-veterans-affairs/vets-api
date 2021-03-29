require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attr_accessor :id, :name, :description, :communication_permission
    end
  end
end
