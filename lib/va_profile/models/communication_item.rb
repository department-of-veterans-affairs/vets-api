# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_channel'

module VAProfile
  module Models
    class CommunicationItem < CommunicationBase
      attr_accessor :id, :name
      attr_reader :communication_channels

      validates :id, :communication_channels, presence: true
      validates :communication_channels, length: { maximum: 1, too_long: 'must have only one communication channel' }

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
              communication_item.format_for_api(va_profile_id, include_bio: false, source_date: source_date)
            end,
            vaProfileId: va_profile_id,
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

      def http_verb
        first_communication_channel.communication_permission.id.present? ? :put : :post
      end

      def first_communication_channel
        communication_channels[0]
      end

      def format_for_api(va_profile_id, include_bio: true, source_date: nil)
        communication_channel = first_communication_channel
        source_date = Time.zone.now.iso8601 if source_date.nil?

        attrs = {
          allowed: communication_channel.communication_permission.allowed,
          communicationChannelId: communication_channel.id,
          communicationItemId: id,
          vaProfileId: va_profile_id.to_i,
          sourceDate: source_date
        }.merge(lambda do
          communication_permission = communication_channel.communication_permission

          if communication_permission.id.present?
            { communicationPermissionId: communication_permission.id }
          else
            {}
          end
        end.call)

        include_bio ? { bio: attrs } : attrs
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
