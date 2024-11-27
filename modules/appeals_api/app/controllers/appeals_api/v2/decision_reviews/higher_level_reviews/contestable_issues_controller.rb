# frozen_string_literal: true

class AppealsApi::V2::DecisionReviews::HigherLevelReviews::ContestableIssuesController < AppealsApi::V1::DecisionReviews::BaseContestableIssuesController # rubocop:disable Layout/LineLength
  # This is overwritten so that we can more correctly format errors from caseflow when we get a 404 - all other
  # behavior should match the original method in BaseContestableIssuesController.

  before_action :validate_receipt_date_header!, only: %i[index]

  AMA_ACTIVATION_DATE = Date.new(2019, 2, 19)

  def index
    get_contestable_issues_from_caseflow
    if caseflow_response_has_a_body_and_a_status?
      if caseflow_response.status == 404
        render json: {
          errors: [
            {
              title: 'Not found',
              detail: 'Appeals data for a veteran with that SSN was not found',
              code: 'CASEFLOWSTATUS404',
              status: '404'
            }
          ]
        }, status: :not_found
      else
        render_response(caseflow_response)
      end
    else
      render_unusable_response_error
    end
  end

  private

  # rubocop:disable Metrics/MethodLength
  def validate_receipt_date_header!
    unless Date.parse(request_headers['X-VA-Receipt-Date']).after?(AMA_ACTIVATION_DATE)
      error = {
        title: I18n.t('appeals_api.errors.titles.validation_error'),
        detail: I18n.t('appeals_api.errors.receipt_date_too_early'),
        source: {
          header: 'X-VA-Receipt-Date'
        },
        status: '422'
      }
      render json: { errors: [error] }, status: :unprocessable_entity
    end
  rescue Date::Error # If date cannot be parsed
    error = {
      title: I18n.t('appeals_api.errors.titles.validation_error'),
      detail: 'Receipt date has an invalid format. Use yyyy-mm-dd.',
      source: {
        header: 'X-VA-Receipt-Date'
      },
      status: '422'
    }
    render json: { errors: [error] }, status: :unprocessable_entity
  end
  # rubocop:enable Metrics/MethodLength

  def decision_review_type
    'higher_level_reviews'
  end
end
