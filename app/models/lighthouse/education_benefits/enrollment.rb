# frozen_string_literal: true

module Lighthouse
  module EducationBenefits
    # The Enrollment model represents an enrollment of a veteran in an education program.
    # This model is used to parse and manipulate the enrollment data returned from the Lighthouse API.
    # It includes ActiveModel::Model to get some of the ActiveRecord features, such as validations and conversions,
    # but it does not persist data to a database.
    class Enrollment
      include ActiveModel::Model
      attr_accessor :begin_date, :end_date, :facility_code, :facility_name, :participant_id,
                    :training_type, :term_id, :hour_type, :full_time_hours,
                    :full_time_credit_hour_under_grad, :vacation_day_count, :on_campus_hours,
                    :online_hours, :yellow_ribbon_amount, :status, :amendments

      def initialize(attributes = {})
        super(attributes.deep_transform_keys { |key| key.to_s.underscore })
      end

      # existing data contracts rely on eg `begin_date` so we must
      # modify some of the field names
      def begin_date_time=(value)
        @begin_date = value
      end

      def end_date_time=(value)
        @end_date = value
      end
    end
  end
end
