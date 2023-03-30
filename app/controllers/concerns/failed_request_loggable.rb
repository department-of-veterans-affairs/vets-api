# frozen_string_literal: true

module FailedRequestLoggable
  extend ActiveSupport::Concern

  class_methods do
    def exception_hash(exception)
      hash = {}
      %i[
        as_json attributes backtrace body errors
        inspect instance_values key message
        original_body original_status
        response_values sentry_type
        serializable_hash status status_code
        to_a to_h to_json to_s
      ].each do |method|
        hash[method] = exception.send method
      rescue
        nil
      end
      hash
    end
  end

  private

  def current_user_hash
    hash = {}

    %i[first_name last_name birls_id icn edipi mhv_correlation_id participant_id vet360_id ssn]
      .each { |key| hash[key] = @current_user.try(key) }

    hash[:assurance_level] = begin
      @current_user.loa[:current]
    rescue
      nil
    end

    hash[:birth_date] = begin
      @current_user.birth_date_mpi.to_date.iso8601
    rescue
      nil
    end

    hash
  end

  def log_exception_to_personal_information_log(exception, error_class:, **additional_data)
    data = {
      user: current_user_hash,
      error: self.class.exception_hash(exception)
    }
    data[:additional_data] = additional_data if additional_data.present?

    PersonalInformationLog.create! error_class:, data:
  end
end
