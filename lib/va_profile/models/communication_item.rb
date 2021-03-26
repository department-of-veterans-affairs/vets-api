require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < Base
      # TODO add validation
      attribute :id, Integer
      attribute :name, String
      attribute :va_profile_id, Integer

      attribute :communication_channels, Array[VAProfile::Models::CommunicationChannel]

      def http_verb
        communication_channels[0].communication_permission.id.present? ? :put : :post
      end

      def in_json
        communication_channel = communication_channels[0]

        {
          bio: {
            allowed: communication_channel.communication_permission.allowed,
            communicationChannelId: communication_channel.id,
            communicationItemId: id,
            vaProfileId: va_profile_id,
            sourceDate: Time.zone.now.iso8601
          }.merge(lambda do
            communication_permission = communication_channel.communication_permission

            if communication_permission.id.present?
              { communicationPermissionId: communication_permission.id }
            else
              {}
            end
          end.call)
        }.to_json
      end
    end
  end
end
