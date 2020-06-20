# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/vbms_uploader'

module ClaimsApi
  class PoaFormBuilderJob
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find power_of_attorney_id
      signed_pdf = power_of_attorney.sign_pdf
      pdf_constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
      page1 = pdf_constructor.fill_pdf(signed_pdf[:page1], 1)
      page2 = pdf_constructor.fill_pdf(signed_pdf[:page2], 2)
      output_path = "/tmp/#{power_of_attorney_id}_final.pdf"
      pdf = CombinePDF.new
      pdf << CombinePDF.load(page1)
      pdf << CombinePDF.load(page2)
      pdf.save(output_path)
      upload_to_vbms(power_of_attorney, output_path)
    end

    def upload_to_vbms(power_of_attorney, path)
      uploader = VbmsUploader.new(
        filepath: path,
        file_number: power_of_attorney.auth_headers['va_eauth_pnid'],
        doc_type: '295'
      )
      uploader.upload!
    rescue VBMS::Unknown
      rescue_vbms_error(power_of_attorney)
    rescue Errno::ENOENT
      rescue_file_not_found(power_of_attorney)
    end

    def rescue_file_not_found(power_of_attorney)
      power_of_attorney.update(
        status: 'failed',
        vbms_error_message: 'File could not be retrieved from AWS'
      )
    end
  end
end
