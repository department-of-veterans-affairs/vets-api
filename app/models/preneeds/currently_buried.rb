# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class CurrentlyBuried < Common::Base
    include ActiveModel::Validations

    attribute :cemetery_number, String
    attribute :name, Preneeds::Name

    validates :cemetery_number, format: { with: /\A\d{3}\z/, allow_blank: true }
    validates :name, presence: true, preneeds_embedded_object: true

    def message
      { cemetery_number: cemetery_number, name: name.message }
    end

    def self.permitted_params
      [:cemetery_number, name: Preneeds::Name.permitted_params]
    end
  end
end
