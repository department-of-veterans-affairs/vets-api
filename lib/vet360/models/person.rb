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
    end
  end
end
