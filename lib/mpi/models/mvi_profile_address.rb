# frozen_string_literal: true

module MVI
  module Models
    class MviProfileAddress
      include Virtus.model

      attribute :street, String
      attribute :city, String
      attribute :state, String
      attribute :postal_code, String
      attribute :country, String
    end
  end
end
