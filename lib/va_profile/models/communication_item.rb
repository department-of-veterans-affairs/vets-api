module VAProfile
  module Models
    class CommunicationItem < Base
      attribute :id, Integer
      attribute :name, String

      attribute :communication_item_channels, Array[VAProfile::Models::CommunicationItemChannel]
    end
  end
end
