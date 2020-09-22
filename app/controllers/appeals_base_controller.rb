# frozen_string_literal: true

require 'caseflow/service'
require 'decision_review/service'

class AppealsBaseController < ApplicationController
  include ActionController::Serialization
  before_action { authorize :appeals, :access? }

  private

  def appeals_service
    Caseflow::Service.new
  end

  def decision_review_service
    DecisionReview::Service.new
  end

  def render_error_unless_request_body_is_a_hash
    render_request_body_is_not_a_hash_error unless request_body_hash
  end

  def request_body_hash
    @request_body_hash ||= get_hash_from_request_body
  end

  def get_hash_from_request_body
    return nil if request.body.class.name == 'Puma::NullIO' # testing string b/c NullIO class doesn't always exist

    body = JSON.parse request.body.string
    body.is_a?(Hash) ? body : nil
  rescue JSON::ParserError
    nil
  end

  def render_request_body_is_not_a_hash_error
    status = 422
    error = {
      status: status,
      detail: "The request body isn't a JSON object",
      source: false
    }
    render status: status, json: { errors: [error] }
  end
end
