# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < CommunicationBase
      attr_accessor :id, :name
      attr_reader :communication_channels

      validates :id, :communication_channels, presence: true

      validate :communication_channels_valid

      def self.create_from_api(communication_res, permission_res)
        new(
          id: communication_res['communication_item_id'],
          name: communication_res['common_name'],
          communication_channels: communication_res['communication_item_channels'].map do |communication_item_channel|
            communication_channel = communication_item_channel['communication_channel']

            VAProfile::Models::CommunicationChannel.create_from_api(
              communication_channel,
              communication_res['communication_item_id'],
              permission_res
            )
          end
        )
      end

      def self.format_all_for_api(communication_items, va_profile_id)
        source_date = Time.zone.now.iso8601

        {
          bio: {
            communicationPermissions: communication_items.map do |communication_item|
              communication_item.format_for_api(va_profile_id, source_date)
            end.flatten,
            vaProfileId: va_profile_id.to_i,
            sourceDate: source_date
          }
        }
      end

      def communication_channels=(arr)
        @communication_channels = if arr[0].present? && !arr[0].is_a?(CommunicationChannel)
                                    arr.map do |hash|
                                      CommunicationChannel.new(hash)
                                    end
                                  else
                                    arr
                                  end
      end

      def format_for_api(va_profile_id, source_date)
        communication_channels.map do |communication_channel|
          communication_permission = communication_channel.communication_permission

          {
            allowed: communication_permission.allowed,
            communicationChannelId: communication_channel.id,
            communicationItemId: id,
            vaProfileId: va_profile_id.to_i,
            sourceDate: source_date
          }.merge(lambda do
            if communication_permission.id.present?
              { communicationPermissionId: communication_permission.id }
            else
              {}
            end
          end.call)
        end
      end

      private

      def communication_channels_valid
        communication_channels&.each do |communication_channel|
          unless communication_channel.valid?
            errors.add(:communication_channels, communication_channel.errors.full_messages.join(','))
          end
        end
      end
    end
  end
end
