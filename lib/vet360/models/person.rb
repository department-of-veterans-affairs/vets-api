# frozen_string_literal: true

module Vet360
  module Models
    class Person < Base
      attribute :addresses, Array[Address]
      attribute :created_at, Common::ISO8601Time
      attribute :emails, Array[Email]
      attribute :source_date, Common::ISO8601Time
      attribute :telephones, Array[Telephone]
      attribute :transaction_id, String
      attribute :updated_at, Common::ISO8601Time
      attribute :vet360_id, String

      # Converts a decoded JSON response from Vet360 to an instance of the Person model
      # @param body [Hash] the decoded response body from Vet360
      # @return [Vet360::Models::Person] the model built from the response body
      def self.build_from(body)
        addresses = body['addresses']&.map { |a| Vet360::Models::Address.build_from(a) }
        emails = body['emails']&.map { |e| Vet360::Models::Email.build_from(e) }
        telephones = body['telephones']&.map { |t| Vet360::Models::Telephone.build_from(t) }

        Vet360::Models::Person.new(
          created_at: body['create_date'],
          source_date: body['source_date'],
          updated_at: body['update_date'],
          transaction_id: body['trx_audit_id'],
          addresses: addresses || [],
          emails: emails || [],
          telephones: telephones || [],
          vet360_id: body['vet360_id']
        )
      end
    end
  end
end
