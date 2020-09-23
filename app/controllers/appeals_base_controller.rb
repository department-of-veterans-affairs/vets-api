# frozen_string_literal: true

require 'caseflow/service'
require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'
require 'decision_review/service'

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  class RequestBodyIsNotAHash < Common::Exceptions::BaseError
    def errors
      Array Common::Exceptions::SerializableError.new i18n_data
    end

    def i18n_data
      I18n.t i18n_key
    end

    def i18n_key
      'decision_review.exceptions.DR_REQUEST_BODY_IS_NOT_A_HASH'
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
    raise RequestBodyIsNotAHash if request.body.class.name == 'Puma::NullIO'

    body = JSON.parse request.body.string
    raise RequestBodyIsNotAHash unless body.is_a?(Hash)

    body
  rescue JSON::ParserError
    raise RequestBodyIsNotAHash
  end
end
