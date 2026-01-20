# frozen_string_literal: true

module DependentsVerification
  # @see DependentsVerification::FormProfiles::VA210538
  # app/models/dependents_verification/form_profiles/va_210538.rb
  module PrefillHelpers
    # Calculates the age of a dependent based on their date of birth
    #
    # @param date_of_birth [String] The date of birth of the dependent
    # @return [Integer] The age of the dependent
    def dependent_age(date_of_birth)
      return nil if date_of_birth.blank?

      dob = Date.parse(date_of_birth)
      now = Time.now.utc.to_date

      # If the current month is greater than the birth month,
      # or if it's the same month but the current day is greater than or equal to the birth day,
      # then the birthday has occurred this year.
      # Otherwise, subtract one year additional year from the age.
      after_birthday = now.month > dob.month || (now.month == dob.month && now.day >= dob.day)
      now.year - dob.year - (after_birthday ? 0 : 1)
    end

    # Safely parses a date string, handling various formats
    #
    # @param date_string [String, Date, nil] The date to parse
    # @return [Date, nil] The parsed date or nil if parsing fails
    def parse_date_safely(date_string)
      return nil if date_string.blank?

      DateTime.parse(date_string.to_s).strftime('%m/%d/%Y')
    rescue ArgumentError, TypeError
      nil
    end
  end
end
