# frozen_string_literal: true

require 'vets/model'

module MPI
  module Models
    class MviProfileAddress
      include Vets::Model

      attribute :street, String
      attribute :street2, String
      attribute :city, String
      attribute :state, String
      attribute :postal_code, String
      attribute :country, String
    end
  end
end
