require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < Base
      attribute :id, Integer
      attribute :name, String
      attribute :description, String

      attribute :communication_permission, VAProfile::Models::CommunicationPermission
    end
  end
end
