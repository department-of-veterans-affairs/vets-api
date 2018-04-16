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

      def self.from_response(body)
        addresses = body['addresses']&.map { |a| Vet360::Models::Address.from_response(a) }
        emails = body['emails']&.map { |e| Vet360::Models::Email.from_response(e) }
        telephones = body['telephones']&.map { |t| Vet360::Models::Telephone.from_response(t) }

        Vet360::Models::Person.new(
          created_at: body['create_date'],
          source_date: body['source_date'],
          updated_at: body['update_date'],
          transaction_id: body['trx_audit_id'],
          # @TODO should these be nil or [] when empty?
          addresses: body['addresses']&.map { |a| Vet360::Models::Address.from_response(a) },
          emails: body['emails']&.map { |e| Vet360::Models::Telephone.from_response(e) },
          telephones: body['telephones']&.map { |t| Vet360::Models::Telephone.from_response(t) }
          addresses: addresses || [],
          emails: emails || [],
          telephones: telephones || []
        )
      end
    end
  end
end
