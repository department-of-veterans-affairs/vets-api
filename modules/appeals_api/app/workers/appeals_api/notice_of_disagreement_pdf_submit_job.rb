# frozen_string_literal: true

require 'sidekiq'
require 'appeals_api/notice_of_disagreement_pdf_constructor'
require 'appeals_api/upload_error'
require 'central_mail/utilities'
require 'central_mail/service'
require 'pdf_info'

module AppealsApi
  class NoticeOfDisagreementPdfSubmitJob
    include Sidekiq::Worker
    include CentralMail::Utilities

    def perform(notice_of_disagreement_id, retries = 0)
      @retries = retries
      @notice_of_disagreement = NoticeOfDisagreement.find notice_of_disagreement_id
      stamped_pdf = generate_pdf(notice_of_disagreement_id)
      File.delete(stamped_pdf) if File.exist?(stamped_pdf)
    end

    def generate_pdf(notice_of_disagreement_id)
      pdf_constructor = AppealsApi::NoticeOfDisagreementPdfConstructor.new(notice_of_disagreement_id)
      pdf_path = pdf_constructor.fill_pdf
      # notice_of_disagreement.update!(status: 'submitting')
      # pdf_constructor.stamp_pdf(pdf_path, notice_of_disagreement.consumer_name) # TODO Add consumer name to NOD
      pdf_constructor.stamp_pdf(pdf_path, 'Test Consumer')
    end
  end
end
