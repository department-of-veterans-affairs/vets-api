# frozen_string_literal: true

require_relative 'communication_base'
require_relative 'communication_permission'

module VAProfile
  module Models
    class CommunicationChannel < CommunicationBase
      attr_accessor :id, :name, :description, :communication_permission

      validates :id, :communication_permission, presence: true

      validate :communication_permission_valid

      private

      def communication_permission_valid
        if communication_permission.present? && !communication_permission.valid?
          errors.add(:communication_permission, communication_permission.errors.full_messages.join(','))
        end
      end
    end
  end
end
