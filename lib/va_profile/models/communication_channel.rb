require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attribute :id, Types::Strict::Integer
      attribute :name, Types::Strict::String
      attribute :description, Types::Strict::String

      attribute :communication_permission?, VAProfile::Models::CommunicationPermission
    end
  end
end
