# frozen_string_literal: true

require 'rails_helper'
require 'appeals_api/decision_review_report'

describe AppealsApi::DecisionReviewReport do
  it 'can correctly calculate hlrs' do
    create :higher_level_review, created_at: 1.week.ago, status: 'success'
    create :higher_level_review, status: 'success'
    create :higher_level_review, status: 'success'

    errored_hlr = create :higher_level_review, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.successful_hlr_count).to eq(2)
    expect(subject.hlr_with_errors).to eq([errored_hlr])
  end

  it 'can correctly calculate nods' do
    create :notice_of_disagreement, created_at: 1.week.ago, status: 'success'
    create :notice_of_disagreement, status: 'success'
    create :notice_of_disagreement, status: 'success'

    errored_nod = create :notice_of_disagreement, :status_error

    subject = described_class.new(from: 5.days.ago, to: Time.now.utc)

    expect(subject.successful_nod_count).to eq(2)
    expect(subject.nod_with_errors).to eq([errored_nod])
  end
end
