# frozen_string_literal: true

module AskVAApi
  module Zipcodes
    class Serializer < ActiveModel::Serializer
      include JSONAPI::Serializer
      set_type :zipcodes

      attributes :zipcode,
                 :city,
                 :state,
                 :lat,
                 :lng
    end
  end
end
