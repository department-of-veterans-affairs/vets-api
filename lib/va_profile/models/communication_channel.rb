# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attr_accessor :id, :name, :description, :default_send_indicator
      attr_reader :communication_permission

      validates :id, :communication_permission, presence: true

      validate :communication_permission_valid

      def self.create_from_api(communication_channel_data,
                               communication_item_id,
                               default_send_indicator,
                               permission_res)
        communication_channel_model = new(
          id: communication_channel_data['communication_channel_id'],
          name: communication_channel_data['name'],
          description: communication_channel_data['description'],
          default_send_indicator:
        )

        permission = permission_res['bios']&.find do |permission_data|
          permission_data['communication_item_id'] == communication_item_id &&
            permission_data['communication_channel_id'] == communication_channel_data['communication_channel_id']
        end

        if permission.present?
          communication_channel_model.communication_permission = VAProfile::Models::CommunicationPermission.new(
            id: permission['communication_permission_id'],
            allowed: permission['allowed']
          )
        end

        communication_channel_model
      end

      def communication_permission=(permission)
        @communication_permission = if permission.present? && !permission.is_a?(CommunicationPermission)
                                      CommunicationPermission.new(permission)
                                    else
                                      permission
                                    end
      end

      private

      def communication_permission_valid
        if communication_permission.present? && communication_permission.invalid?
          errors.add(:communication_permission, communication_permission.errors.full_messages.join(','))
        end
      end
    end
  end
end
