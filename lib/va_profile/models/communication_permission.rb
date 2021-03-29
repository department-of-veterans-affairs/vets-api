module VAProfile
  module Models
    class CommunicationPermission < CommunicationBase
      attribute :id, Types::Strict::Integer
      attribute :allowed, Types::Strict::Bool
    end
  end
end
