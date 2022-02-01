# frozen_string_literal: true

module MPI
  module Models
    class MviProfileAddress
      include Virtus.model

      attribute :street, String
      attribute :street2, String
      attribute :city, String
      attribute :state, String
      attribute :postal_code, String
      attribute :country, String
    end
  end
end
