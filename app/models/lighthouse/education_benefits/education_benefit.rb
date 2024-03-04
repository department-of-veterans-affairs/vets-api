# frozen_string_literal: true

require 'active_support/inflector'

module Lighthouse
  module EducationBenefits
    # The EducationBenefit model represents a veteran's education benefit status.
    # This model is used to parse and manipulate the data returned from the Lighthouse API.
    # It includes ActiveModel::Model to get some of the ActiveRecord features, such as validations and conversions,
    # but it does not persist data to a database.
    class EducationBenefit
      include ActiveModel::Model
      attr_accessor :first_name, :last_name, :name_suffix, :date_of_birth, :va_file_number, :active_duty,
                    :veteran_is_eligible, :regional_processing_office, :eligibility_date,
                    :percentage_benefit, :original_entitlement, :used_entitlement,
                    :remaining_entitlement
      attr_reader :enrollments

      def initialize(attributes = {})
        super(attributes.deep_transform_keys { |key| key.to_s.underscore })
      end

      def enrollments=(values)
        @enrollments = values.map do |value|
          Enrollment.new(value)
        end
      end

      # existing data contracts rely on eg `date_of_birth` so we must
      # modify some of the field names
      def date_time_of_birth=(value)
        @date_of_birth = value
      end

      def delimiting_date_time=(value)
        @delimiting_date = value
      end

      def eligibility_date_time=(value)
        @eligibility_date = value
      end
    end
  end
end
