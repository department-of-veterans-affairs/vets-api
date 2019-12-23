# frozen_string_literal: true

module Vet360
  module Models
    class Permission < Base
      include Vet360::Concerns::Defaultable

      TEXT = 'TextPermission'
      PERMISSION_TYPES = [TEXT].freeze

      attribute :created_at, Common::ISO8601Time
      attribute :effective_end_date, Common::ISO8601Time
      attribute :effective_start_date, Common::ISO8601Time
      attribute :id, Integer
      attribute :permission_type, String
      attribute :permission_value, Boolean
      attribute :source_date, Common::ISO8601Time
      attribute :source_system_user, String
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
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
      # use in the body of a request to Vet360
      #
      # @return [String] JSON-encoded string suitable for requests to Vet360
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

      # Converts a decoded JSON response from Vet360 to an instance of the Permission model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Permission] the model built from the response body
      def self.build_from(body)
        Vet360::Models::Permission.new(
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
