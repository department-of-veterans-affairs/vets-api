# frozen_string_literal: true

require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'
require './lib/evss/disability_compensation_form/form526_to_lighthouse_transform'

class LighthouseGeneratePdfProvider
  include GeneratePdfProvider

  def initialize(icn)
    @icn = icn
  end

  def generate_526_pdf(form_content, transaction_id)
    body = transform_service.transform(JSON.parse(form_content))
    service.submit526(body, nil, nil, { generate_pdf: true, transaction_id: })
  end

  def transform_service
    @transform_service ||= EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
  end

  def service
    @service ||= BenefitsClaims::Service.new(@icn)
  end
end
