# frozen_string_literal: true

class AppealsApi::V1::DecisionReview::ContestableIssuesController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  EXPECTED_HEADERS = %w[veteranId receiptDate]

  def index
    render_response(Appeals::Service.new.get_contestable_issues(headers))
  end

  def headers
    EXPECTED_HEADERS.reduce({}) do |hash, key|
      hash.merge(key => request.headers[key])
    end
  end 
end
