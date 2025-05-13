# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attr_accessor :id, :name, :description,
                    :default_send_indicator,
                    :sensitive_indicator,
                    :default_sensitive_indicator
      attr_reader :communication_permission

      validates :id, :communication_permission, presence: true

      validate :communication_permission_valid

      def self.create_from_api(communication_channel_data,
                               communication_item_id,
                               item_channel_data,
                               permission_res)
        communication_channel_model = new(
          id: communication_channel_data['communication_channel_id'],
          name: communication_channel_data['name'],
          description: communication_channel_data['description'],
          default_send_indicator: item_channel_data['default_send_indicator']
        )

        assign_channel_sensitive_indicators(communication_channel_model, item_channel_data)

        permission = permission_res['bios']&.find do |permission_data|
          permission_data['communication_item_id'] == communication_item_id &&
            permission_data['communication_channel_id'] == communication_channel_data['communication_channel_id']
        end

        assign_permission(communication_channel_model, permission) if permission.present?

        communication_channel_model
      end

      def self.sensitive_indicators_present?(communication_data, *keys)
        keys.all? { |key| !communication_data[key].nil? }
      end

      def self.assign_channel_sensitive_indicators(model, item_data)
        # We expect sensitive_indicator and default_sensitive_indicator to be provided together
        return unless sensitive_indicators_present?(item_data, 'sensitive_indicator', 'default_sensitive_indicator')

        model.sensitive_indicator = item_data['sensitive_indicator']
        model.default_sensitive_indicator = item_data['default_sensitive_indicator']
      end

      def self.assign_permission(model, permission)
        model.communication_permission = VAProfile::Models::CommunicationPermission.new(
          id: permission['communication_permission_id'],
          allowed: permission['allowed']
        )

        if sensitive_indicators_present?(permission, 'sensitive')
          model.communication_permission.sensitive = permission['sensitive']
        end
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

      private_class_method :sensitive_indicators_present?,
                           :assign_channel_sensitive_indicators,
                           :assign_permission
    end
  end
end
