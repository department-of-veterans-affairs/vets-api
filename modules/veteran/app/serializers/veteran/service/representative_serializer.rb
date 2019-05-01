# frozen_string_literal: true

module Veteran
  module Service
    class RepresentativeSerializer < ActiveModel::Serializer
      attribute :first_name
      attribute :last_name
      attribute :poa
    end
  end
end
