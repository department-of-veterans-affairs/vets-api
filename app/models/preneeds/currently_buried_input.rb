# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class CurrentlyBuriedInput < Common::Base
    include ActiveModel::Validations

    validates :name, presence: true
    validates :cemetery_number, format: { with: /\A\d{3}\z/, allow_blank: true }

    attribute :cemetery_number, String
    attribute :name, NameInput
  end
end
