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
        Vet360::Models::Person.new(
          addresses: body['addresses'].map { |a| Vet360::Models::Address.from_response(a) },
          emails: body['emails'].map { |e| Vet360::Models::Telephone.from_response(e) },
          telephones: body['telephones'].map { |t| Vet360::Models::Telephone.from_response(t) }
        )
      end
    end
  end
end
