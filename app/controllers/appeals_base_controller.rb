# frozen_string_literal: true

require 'caseflow/service'
require 'decision_review/service'

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  class << self
    def exception_hash(exception)
      %i[
        message
        backtrace
        key
        response_values
        original_status
        original_body
      ].reduce({}) { |hash, key| hash.merge({ key => exception.try(key) }) }
    end
  end

  private

  def appeals_service
    Caseflow::Service.new
  end

  def decision_review_service
    DecisionReview::Service.new
  end

  def request_body_hash
    @request_body_hash ||= get_hash_from_request_body
  end

  def get_hash_from_request_body
    # testing string b/c NullIO class doesn't always exist
    raise request_body_is_not_a_hash_error if request.body.class.name == 'Puma::NullIO'

    body = JSON.parse request.body.string
    raise request_body_is_not_a_hash_error unless body.is_a?(Hash)

    body
  rescue JSON::ParserError
    raise request_body_is_not_a_hash_error
  end

  def request_body_is_not_a_hash_error
    DecisionReview::ServiceException.new key: 'DR_REQUEST_BODY_IS_NOT_A_HASH'
  end

  def request_body_debug_data
    {
      request_body_class_name: request.try(:body).class.name,
      request_body_string: request.try(:body).try(:string)
    }
  end

  def current_user_hash
    hash = {}

    %i[
      first_name
      last_name
      birls_id
      icn
      edipi
      mhv_correlation_id
      participant_id
      vet360_id
      ssn
    ].each { |key| hash[key] = @current_user.try(key) }

    hash[:assurance_level] = @current_user.try(:loa)&.dig(:current)&.to_s
    hash[:birth_date] = begin
                          @current_user.va_profile.birth_date.to_date.iso8601
                        rescue
                          nil
                        end
    hash
  end

  def log_exception_to_personal_information_log(exception, error_class:, data: {})
    PersonalInformationLog.create!(
      error_class: error_class,
      data: {
        user: current_user_hash,
        error: self.class.exception_hash(exception)
      }.merge(data)
    )
  end
end
