# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class PoaFormBuilderJob
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      power_of_attorney = ClaimsApi::PowerOfAttorney.find power_of_attorney_id
      signed_pdf = power_of_attorney.sign_pdf
      pdf_constructor = ClaimsApi::PowerOfAttorneyPdfConstructor.fill_page_one(power_of_attorney.id)
      page1 = pdf_constructor.fill_pdf(signed_pdf[:page1])
      puts page1
    end
  end
end
