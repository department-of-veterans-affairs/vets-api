module VAProfile
  module Models
    class CommunicationChannel < Base
      attribute :id, Integer
      attribute :name, String
      attribute :description, String
      attribute :allowed, Boolean
    end
  end
end
