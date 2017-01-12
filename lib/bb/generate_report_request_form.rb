# frozen_string_literal: true
require 'common/models/form'

module BB
  class GenerateReportRequestForm < Common::Form
    attribute :from_date, Common::UTCTime
    attribute :to_date, Common::UTCTime
    attribute :data_classes, Array[String]

    attr_reader :client

    validates :from_date, :to_date, :data_classes, presence: true
    validate  :from_date_is_before_to_date
    validate  :data_classes_belongs_to_eligible_data_classes

    def initialize(client, attributes = {})
      super(attributes)
      @client = client
    end

    def params
      { from_date: from_date.try(:httpdate), to_date: to_date.try(:httpdate), data_classes: data_classes }
    end

    private

    def eligible_data_classes
      @eligible_data_classes ||= client.get_eligible_data_classes.data_classes
    end

    def from_date_is_before_to_date
      if from_date.present? && to_date.present? && to_date < from_date
        errors.add(:base, 'From date must occur before to date')
      end
    end

    def data_classes_belongs_to_eligible_data_classes
      ineligible_data_classes = data_classes - eligible_data_classes
      if ineligible_data_classes.any?
        errors.add(:base, "Invalid data classes: #{ineligible_data_classes.join(', ')}")
      end
    end
  end
end
