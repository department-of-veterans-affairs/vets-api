# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/hlr_pdf_constructor'

module AppealsApi
  class HlrPdfSubmitJob
    include Sidekiq::Worker
    PDF_TEMPLATE = Rails.root.join('modules', 'appeals_api', 'config', 'pdfs')

    def perform(higher_level_review_id)
      pdf_constructor = AppealsApi::HlrPdfConstructor.new(higher_level_review_id)
      pdf_constructor.fill_pdf
    end
  end
end
