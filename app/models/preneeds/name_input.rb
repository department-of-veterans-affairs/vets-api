# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class NameInput < Common::Base
    include ActiveModel::Validations

    # Some branches have no end_date, but api requires it just the same
    validates :last_name, :first_name, minimum: 5, maximum: 15, allow_blank: false

    attribute :first_name, String
    attribute :last_name, String
  end
end
