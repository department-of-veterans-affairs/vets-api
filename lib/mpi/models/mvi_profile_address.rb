# frozen_string_literal: true

require 'identity/model/inspect'

module MPI
  module Models
    class MviProfileAddress
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Identity::Model::Inspect

      attribute :street,      :string
      attribute :street2,     :string
      attribute :city,        :string
      attribute :state,       :string
      attribute :postal_code, :string
      attribute :country,     :string
    end
  end
end
