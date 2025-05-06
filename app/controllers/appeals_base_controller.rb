# frozen_string_literal: true

require 'caseflow/service'

class AppealsBaseController < ApplicationController
  include FailedRequestLoggable
  before_action { authorize :appeals, :access? }

  private

  def appeals_service
    Caseflow::Service.new
  end

  def request_body_debug_data
    {
      request_body_class_name: request.try(:body).class.name,
      request_body_string: request.try(:body).try(:string)
    }
  end
end
