# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class MilitaryRankRequest < Common::Base
    include ActiveModel::Validations

    # Some branches have no end_date, but api requires it just the same
    validates :start_date, :end_date, presence: true, format: /\A\d{4}-\d{2}-\d{2}\z/
    validates :branch_of_service, format: /\A\w{2}\z/

    attribute :branch_of_service, String
    attribute :start_date, XmlDate
    attribute :end_date, XmlDate
  end
end
