# frozen_string_literal: true

require 'caseflow/service'
require 'decision_review/service'

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  REQUEST_BODY_IS_NOT_A_HASH_ERROR = DecisionReview::ServiceException.new key: 'DR_REQUEST_BODY_IS_NOT_A_HASH'

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
    raise REQUEST_BODY_IS_NOT_A_HASH_ERROR if request.body.class.name == 'Puma::NullIO'

    body = JSON.parse request.body.string
    raise REQUEST_BODY_IS_NOT_A_HASH_ERROR unless body.is_a?(Hash)

    body
  rescue JSON::ParserError
    raise REQUEST_BODY_IS_NOT_A_HASH_ERROR
  end
end
