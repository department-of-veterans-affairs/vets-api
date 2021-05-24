# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
module Swagger
  module Schemas
    module Vet360
      module CommunicationPermission
        def self.extended(base)
          base.parameter do
            key :name, :permission_data
            key :in, :body
            key :description, 'Communication permission details'
            key :required, true

            schema do
              key :type, :object
              key :required, %i[communication_item]

              property :communication_item do
                key :type, :object
                key :required, %i[id communication_channel]

                property :id, type: :integer

                property :communication_channel do
                  key :type, :object
                  key :required, %i[id communication_permission]

                  property :id, type: :integer

                  property :communication_permission do
                    key :type, :object
                    key :required, %i[allowed]

                    property :allowed, type: :boolean
                  end
                end
              end
            end
          end

          base.response 200 do
            key :description, 'Create or update communication permission response'

            schema do
              key :type, :object

              property :tx_audit_id, type: :string
              property :status, type: :string

              property :bio do
                key :type, :object

                property :create_date, type: :string
                property :update_date, type: :string
                property :tx_audit_id, type: :string
                property :source_system, type: :string
                property :source_date, type: :string
                property :communication_permission_id, type: :integer
                property :va_profile_id, type: :integer
                property :communication_channel_id, type: :integer
                property :communication_item_id, type: :integer
                property :communication_channel_name, type: :string
                property :communication_item_common_name, type: :string
                property :allowed, type: :boolean
              end
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
