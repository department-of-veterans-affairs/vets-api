# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class Permission < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable

      TEXT = 'TextPermission'
      PERMISSION_TYPES = [TEXT].freeze

      attribute :created_at, Vets::Type::ISO8601Time
      attribute :effective_end_date, Vets::Type::ISO8601Time
      attribute :effective_start_date, Vets::Type::ISO8601Time
      attribute :id, Integer
      attribute :permission_type, String
      attribute :permission_value, Bool
      attribute :source_date, Vets::Type::ISO8601Time
      attribute :source_system_user, String
      attribute :transaction_id, String
      attribute :updated_at, Vets::Type::ISO8601Time
      attribute :vet360_id, String

      validates(
        :permission_type,
        presence: true,
        inclusion: { in: PERMISSION_TYPES }
      )

      validates(
        :permission_value,
        presence: true
      )

      # Converts an instance of the Permission model to a JSON encoded string suitable for
      # use in the body of a request to VAProfile
      #
      # @return [String] JSON-encoded string suitable for requests to VAProfile
      #
      def in_json
        {
          bio: {
            originatingSourceSystem: SOURCE_SYSTEM,
            permissionType: @permission_type,
            permissionValue: @permission_value,
            sourceDate: @source_date,
            sourceSystemUser: @source_system_user,
            permissionId: @id,
            vet360Id: @vet360_id,
            effectiveStartDate: @effective_start_date,
            effectiveEndDate: @effective_end_date
          }
        }.to_json
      end

      # Converts a decoded JSON response from VAProfile to an instance of the Permission model
      # @param body [Hash] the decoded response body from VAProfile
      # @return [VAProfile::Models::Permission] the model built from the response body
      def self.build_from(body)
        VAProfile::Models::Permission.new(
          id: body['permission_id'],
          created_at: body['create_date'],
          permission_type: body['permission_type'],
          permission_value: body['permission_value'],
          source_date: body['source_date'],
          transaction_id: body['tx_audit_id'],
          updated_at: body['update_date'],
          vet360_id: body['vet360_id'],
          effective_end_date: body['effective_end_date'],
          effective_start_date: body['effective_start_date']
        )
      end
    end
  end
end
