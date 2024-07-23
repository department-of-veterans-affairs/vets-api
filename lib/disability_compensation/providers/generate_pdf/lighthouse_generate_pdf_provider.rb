# frozen_string_literal: true

require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'

class LighthouseGeneratePdfProvider
  def initialize(icn)
    @icn = icn
  end

  def generate_526_pdf(form_content)
    body = transform_service.transform(JSON.parse(form_content))
    service.submit526(body, nil, nil, { generate_pdf: true })
  end

  def transform_service
    @transform_service ||= EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
  end

  def service
    @service ||= BenefitsClaims::Service.new(@icn)
  end
end
