# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < CommunicationBase
      attr_accessor :id, :name, :communication_channels
      attr_reader :communication_channel

      validates :id, :communication_channel, presence: true

      validate :communication_channel_valid

      def self.create_from_api(communication_res, permission_res)
        new(
          id: communication_res['communication_item_id'],
          name: communication_res['common_name'],
          communication_channels: communication_res['communication_item_channels'].map do |communication_item_channel|
            communication_channel = communication_item_channel['communication_channel']

            VAProfile::Models::CommunicationChannel.create_from_api(
              communication_channel,
              communication_res['communication_item_id'],
              communication_item_channel,
              permission_res
            )
          end
        )
      end

      def communication_channel=(communication_channel_data)
        @communication_channel =
          if communication_channel_data.present? && !communication_channel_data.is_a?(CommunicationChannel)
            CommunicationChannel.new(communication_channel_data)
          else
            communication_channel_data
          end
      end

      def http_verb
        communication_channel.communication_permission.id.present? ? :put : :post
      end

      def in_json(va_profile_id)
        {
          bio: {
            allowed: communication_channel.communication_permission.allowed,
            sensitive: communication_channel.communication_permission.sensitive,
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
        if communication_channel.present? && communication_channel.invalid?
          errors.add(:communication_channel, communication_channel.errors.full_messages.join(','))
        end
      end
    end
  end
end
