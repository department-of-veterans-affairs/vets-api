module VAProfile
  module Models
    class CommunicationPermission < Base
      attribute :id, Integer
      attribute :allowed, Boolean
    end
  end
end
