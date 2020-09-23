# frozen_string_literal: true

require 'caseflow/service'
require 'decision_review/service'
require_relative 'appeals_base_controller/request_body_is_not_a_hash_error.rb'

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
