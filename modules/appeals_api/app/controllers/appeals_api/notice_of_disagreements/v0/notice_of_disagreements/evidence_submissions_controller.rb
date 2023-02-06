# frozen_string_literal: true

module AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreements
  # rubocop:disable Layout/LineLength
  class EvidenceSubmissionsController < AppealsApi::V2::DecisionReviews::NoticeOfDisagreements::EvidenceSubmissionsController
    # rubocop:enable Layout/LineLength
    include AppealsApi::OpenidAuth

    OAUTH_SCOPES = {
      GET: %w[appeals/NoticeOfDisagreements.read],
      PUT: %w[appeals/NoticeOfDisagreements.write],
      POST: %w[appeals/NoticeOfDisagreements.write]
    }.freeze

    private

    def token_validation_api_key
      Settings.dig(:modules_appeals_api, :token_validation, :notice_of_disagreements, :api_key)
    end
  end
end
