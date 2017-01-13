# frozen_string_literal: true
require 'common/models/form'

module BB
  class GenerateReportRequestForm < Common::Form
    attribute :from_date, Common::UTCTime
    attribute :to_date, Common::UTCTime
    attribute :data_classes, Array[String]

    attr_reader :client

    validates :from_date, :to_date, date: true
    # leaving this validation out for now, will test and see if it is required or if
    # MHV error is preferable.
    # validates :from_date, date: { before: :to_date, message: 'must be before to date' }
    validates :data_classes, presence: true
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

    def data_classes_belongs_to_eligible_data_classes
      ineligible_data_classes = data_classes - eligible_data_classes
      if ineligible_data_classes.any?
        errors.add(:base, "Invalid data classes: #{ineligible_data_classes.join(', ')}")
      end
    end
  end
end
