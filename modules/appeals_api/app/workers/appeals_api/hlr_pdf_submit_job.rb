# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/hlr_pdf_constructor'

module AppealsApi
  class HlrPdfSubmitJob
    include Sidekiq::Worker

    def perform(higher_level_review_id)
      pdf_constructor = AppealsApi::HlrPdfConstructor.new(higher_level_review_id)
      pdf_constructor.fill_pdf
      # set status to pending upload
      HigherLevelReview.update(higher_level_review_id, status: 'pending_upload')
      # send to central mail
    end
  end
end
