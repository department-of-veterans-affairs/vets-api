# frozen_string_literal: true

class AppealsApi::V1::DecisionReview::ContestableIssuesController < AppealsApi::ApplicationController
  def index
    render_response(Appeals::Service.new.get_contestable_issues(headers: request.headers.except("apikey")))
  end
end
