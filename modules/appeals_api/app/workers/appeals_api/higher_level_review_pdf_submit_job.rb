# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/higher_level_review_pdf_constructor'

module AppealsApi
  class HigherLevelReviewPdfSubmitJob
    include Sidekiq::Worker

    def perform(higher_level_review_id)
      pdf_constructor = AppealsApi::HigherLevelReviewPdfConstructor.new(higher_level_review_id)
      pdf_constructor.fill_pdf
      # set status to processing until the central mail upload
      HigherLevelReview.update(higher_level_review_id, status: 'processing')
      # send to central mail
    end
  end
end
