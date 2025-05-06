# frozen_string_literal: true

module FormValidation
  extend ActiveSupport::Concern

  def validate_form_with_retries(schema, parsed_form, max_attempts = 3)
    attempts = 0

    begin
      attempts += 1
      errors_array = JSON::Validator.fully_validate(schema, parsed_form, { errors_as_objects: true })
      if attempts > 1
        Rails.logger.info("Form validation in #{self.class} succeeded on attempt #{attempts}/#{max_attempts}")
      end
      errors_array
    rescue => e
      handle_validate_form_with_retries_exception(e, attempts, max_attempts, schema, parsed_form)

      retry if attempts <= max_attempts
    end
  end

  private

  def handle_validate_form_with_retries_exception(e, attempts, max_attempts, schema, parsed_form)
    if attempts <= max_attempts
      Rails.logger.warn(
        "Retrying form validation in #{self.class} due to error: #{e.message} (Attempt #{attempts}/#{max_attempts})"
      )
      sleep(1) # Delay 1 second between retries
    else
      PersonalInformationLog.create(data: {
                                      schema:, parsed_form:,
                                      params: {
                                        errors_as_objects: true
                                      }
                                    },
                                    error_class: "#{self.class} FormValidationError")
      Rails.logger.error(
        "Error during form validation in #{self.class} after maximum retries", { error: e.message,
                                                                                 backtrace: e.backtrace }
      )
      raise
    end
  end
end
