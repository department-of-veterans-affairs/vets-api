# frozen_string_literal: true
require 'preneeds/models/attribute_types/xml_date'
require 'common/models/base'

module Preneeds
  class ServiceRecordInput < Common::Base
    include ActiveModel::Validations

    validates :branch_of_service, length: { is: 2 }, presence: true
    validates :discharge_type, inclusion: { in: %w(1 2 3 4 5 6 7) }
    validates :entered_on_duty_date, :release_from_duty_date,
              format: { with: /\A\d{4}-\d{2}-\d{2}\z/, allow_blank: true }
    validates :national_guard_state, length: { maximum: 3 }

    attribute :branch_of_service, String
    attribute :discharge_type, String
    attribute :entered_on_duty_date, XmlDate
    attribute :highest_rank, String
    attribute :national_guard_state, String
    attribute :release_from_duty_date, XmlDate

    def message
      hash = {
        branch_of_service: branch_of_service, discharge_type: discharge_type,
        entered_on_duty_date: entered_on_duty_date, highest_rank: highest_rank,
        national_guard_state: national_guard_state, release_from_duty_date: release_from_duty_date
      }

      [:entered_on_duty_date, :release_from_duty_date, :highest_rank, :national_guard_state].each do |key|
        hash.delete(key) if hash[key].nil?
      end
      hash
    end
  end
end
