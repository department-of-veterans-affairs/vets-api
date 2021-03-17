require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < Base
      attribute :id, Integer
      attribute :name, String

      attribute :communication_channels, Array[VAProfile::Models::CommunicationChannel]
    end
  end
end
