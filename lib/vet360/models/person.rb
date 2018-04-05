# frozen_string_literal: true

module Vet360
  module Models
    class Person < Base
      attribute :emails, Array[Email]
      attribute :telephones, Array[Telephone]
    end
  end
end
