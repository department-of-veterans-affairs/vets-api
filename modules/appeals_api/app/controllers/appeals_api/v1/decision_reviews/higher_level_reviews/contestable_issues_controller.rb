# frozen_string_literal: true

class AppealsApi::V1::DecisionReviews::HigherLevelReviews::ContestableIssuesController < AppealsApi::ApplicationController
  skip_before_action(:authenticate)

  EXPECTED_HEADERS = %w[X-VA-SSN X-VA-Receipt-Date].freeze

  def index
    render_response get_contestable_issues
  end

  private

  def get_contestable_issues
    Caseflow::Service.new.get_contestable_issues headers: headers, benefit_type: benefit_type
  end

  def benefit_type
    params[:benefit_type]
  end

  def headers
    EXPECTED_HEADERS.reduce({}) do |hash, key|
      hash.merge(key => request.headers[key])
    end
  end
end
