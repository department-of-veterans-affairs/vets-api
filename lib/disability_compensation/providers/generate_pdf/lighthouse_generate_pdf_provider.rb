# frozen_string_literal: true

require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'

class LighthouseGeneratePdfProvider
  # [wipn8923] this doesn't actually do anything...?
  # include ClaimsServiceProvider

  def initialize(icn)
    @icn = icn
  end

  # [wipn8923] START HERE - get more granular with test, not returning a response
  def generate_526_pdf(form_content)
    service.submit526(form_content, nil, nil, { generate_pdf: true })
  end

  def service
    @service ||= BenefitsClaims::Service.new(@icn)
  end
end
