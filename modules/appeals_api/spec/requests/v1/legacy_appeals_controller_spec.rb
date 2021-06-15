# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReviews::LegacyAppealsController, type: :request do
  describe '#index' do

  end

  private

  def get_legacy_appeals(ssn: '872958715', file_number: nil)
    headers = {}

    if file_number.present?
      headers['X-VA-File-Number'] = file_number
    elsif ssn.present?
      headers['X-VA-SSN'] = ssn
    end

    get("/services/appeals/v1/decision_reviews/legacy_appeals/",
        headers: headers)
  end
end
