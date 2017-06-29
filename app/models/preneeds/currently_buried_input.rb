# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class CurrentlyBuriedInput < Common::Base
    include ActiveModel::Validations

    validate :validate_name, if: -> (v) { v.name.present? }

    validates :name, presence: true
    validates :cemetery_number, format: { with: /\A\d{3}\z/, allow_blank: true }

    attribute :cemetery_number, String
    attribute :name, NameInput

    def message
      { cemetery_number: cemetery_number, name: name.message }
    end

    def self.permitted_params
      [:cemetery_number, name: NameInput.permitted_params]
    end

    private

    def validate_name
      errors.add(:name, name.errors.full_messages.join(', ')) unless name.valid?
    end
  end
end
