require_relative 'communication_base'
require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < CommunicationBase
      attr_accessor :id, :name, :communication_channels

      validates :id, :communication_channels, presence: true
      validates :communication_channels, length: { maximum: 1, too_long: 'must have only one communication channel' }

      validate :communication_channel_valid

      def http_verb
        communication_channels[0].communication_permission.id.present? ? :put : :post
      end

      def first_communication_channel
        communication_channels[0]
      end

      def in_json(va_profile_id)
        communication_channel = first_communication_channel

        {
          bio: {
            allowed: communication_channel.communication_permission.allowed,
            communicationChannelId: communication_channel.id,
            communicationItemId: id,
            vaProfileId: va_profile_id.to_i,
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

      private

      def communication_channel_valid
        if communication_channels.present? && !first_communication_channel.valid?
          errors.add(:communication_channels, first_communication_channel.errors.full_messages.join(','))
        end
      end
    end
  end
end
