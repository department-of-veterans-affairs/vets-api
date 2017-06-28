# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class ServiceRecordInput < Common::Base
    include ActiveModel::Validations

    validates :branch_of_service_code, length: { is: 2 }
    validates :discharge_type, inclusion: { in: %w(1 2 3 4 5 6 7) }
    validates :entered_on_duty_date, :release_from_duty_date,
              format: { with: /\A\d{4}-\d{2}-\d{2}\z/, allow_blank: true }
    validates :national_guard_state, length: { maximum: 3 }

    attribute :branch_of_service_code, String
    attribute :discharge_type, String
    attribute :entered_on_duty_date, XmlDate
    attribute :highest_rank, String
    attribute :national_guard_state, String
    attribute :release_from_duty_date, XmlDate
  end
end
