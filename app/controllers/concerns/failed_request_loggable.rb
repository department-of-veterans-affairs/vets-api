# frozen_string_literal: true

module FailedRequestLoggable
  extend ActiveSupport::Concern

  class_methods do
    def exception_hash(exception)
      %i[message backtrace key response_values original_status original_body]
        .reduce({}) { |hash, key| hash.merge({ key => exception.try(key) }) }
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
                          @current_user.va_profile.birth_date.to_date.iso8601
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

    PersonalInformationLog.create! error_class: error_class, data: data
  end
end
