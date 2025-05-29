# frozen_string_literal: true

module BGSDependentsV2
  class ChildMarriage < Base
    # @!attribute child_marriage
    #   @return [Hash] data about the child's marriage
    #
    attribute :date_married, String
    attribute :ssn, String
    attribute :birth_date, String
    attribute :dependent_income, String
    attribute :full_name, FormFullName

    def initialize(child_marriage)
      super
      @date_married = child_marriage['date_married']
      @ssn = child_marriage['ssn']
      @birth_date = child_marriage['birth_date']
      @dependent_income = formatted_boolean(child_marriage['dependent_income'])
      @full_name = child_marriage['full_name']
    end

    def format_info
      {
        event_date: @date_married,
        ssn:,
        birth_date:,
        ever_married_ind: 'Y',
        dependent_income:
      }.merge(@full_name).with_indifferent_access
    end
  end
end
