# frozen_string_literal: true

module AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements
  # rubocop:disable Layout/LineLength
  class EvidenceSubmissionsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController
    # rubocop:enable Layout/LineLength
    include AppealsApi::OpenidAuth
  end
end
