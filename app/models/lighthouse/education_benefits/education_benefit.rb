module Lighthouse
    module EducationBenefits
      # The EducationBenefit model represents a veteran's education benefit status.
      # This model is used to parse and manipulate the data returned from the Lighthouse API.
      # It includes ActiveModel::Model to get some of the ActiveRecord features, such as validations and conversions,
      # but it does not persist data to a database.
      class EducationBenefit
        include ActiveModel::Model
        attr_accessor :first_name, :last_name, :name_suffix, :date_of_birth, :date_time_of_birth, :va_file_number, :active_duty, :veteran_is_eligible, :regional_processing_office, :eligibility_date, :eligibility_date_time, :delimiting_date, :delimiting_date_time, :percentage_benefit, :original_entitlement, :used_entitlement, :remaining_entitlement, :enrollments
  
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
  
      # The Enrollment model represents an enrollment of a veteran in an education program.
      # This model is used to parse and manipulate the enrollment data returned from the Lighthouse API.
      # It includes ActiveModel::Model to get some of the ActiveRecord features, such as validations and conversions,
      # but it does not persist data to a database.
      class Enrollment
        include ActiveModel::Model
        attr_accessor :begin_date, :begin_date_time, :end_date, :end_date_time, :facility_code, :facility_name, :participant_id, :training_type, :term_id, :hour_type, :full_time_hours, :full_time_credit_hour_under_grad, :vacation_day_count, :on_campus_hours, :online_hours, :yellow_ribbon_amount, :status, :amendments
  
        def initialize(attributes = {})
          super(attributes.deep_transform_keys { |key| key.to_s.underscore })
        end

        def begin_date_time=(value)
            @begin_date = value
        end

        def end_date_time=(value)
            @end_date = value
        end
      end
    end
  end