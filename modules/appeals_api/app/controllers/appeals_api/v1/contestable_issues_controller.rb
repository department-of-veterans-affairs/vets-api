# frozen_string_literal: true

class AppealsApi::V1::ContestableIssuesController < AppealsApi::ApplicationController
  #skip_before_action(:authenticate)

  def index
    render_response(Appeals::Service.new.get_contestable_issues(headers: request.headers))
  end
end
