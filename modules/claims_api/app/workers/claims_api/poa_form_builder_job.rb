# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class PoaFormBuilderJob
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find power_of_attorney_id
      signed_pdf = power_of_attorney.sign_pdf
      pdf_constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.new(power_of_attorney.id)
      page1 = pdf_constructor.fill_pdf(signed_pdf[:page1], 1)
      page2 = pdf_constructor.fill_pdf(signed_pdf[:page2], 2)
      output_path = "#{power_of_attorney_id}_final.pdf"
      pdf = CombinePDF.new
      pdf << CombinePDF.load(page1)
      pdf << CombinePDF.load(page2)
      pdf.save(output_path)
      `open #{output_path}`
      output_path
    end
  end
end
