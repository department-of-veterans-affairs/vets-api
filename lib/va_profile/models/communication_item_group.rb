module VAProfile
  module Models
    class CommunicationItemGroup < Base
      attribute :name, String
      attribute :description, String

      attribute :communication_items, Array[VAProfile::Models::CommunicationItem]
    end
  end
end
