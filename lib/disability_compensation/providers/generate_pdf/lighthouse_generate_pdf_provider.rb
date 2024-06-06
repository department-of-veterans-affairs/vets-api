# frozen_string_literal: true

require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'

class LighthouseGeneratePdfProvider
  def initialize(icn)
    @icn = icn
  end

  # [wipn8923] LH provider
  def generate_526_pdf(form_content)
    puts("\n\n wipn8923 :: #{File.basename(__FILE__)}-#{self.class.name}##{__method__.to_s} - \n\t form_content: #{form_content} \n\n")
    puts("\n\n wipn8923 :: #{File.basename(__FILE__)}-#{self.class.name}##{__method__.to_s} - \n\t form_content.class: #{form_content.class} \n\n")

    body = transform_service.transform(JSON.parse(form_content))
    # body = transform_service.transform(form_content)

    puts("\n\n wipn8923 :: #{File.basename(__FILE__)}-#{self.class.name}##{__method__.to_s} - \n\t body: #{body} \n\n")

    service.submit526(body, nil, nil, { generate_pdf: true })
  end

  def transform_service
    @transform_service ||= EVSS::DisabilityCompensationForm::Form526ToLighthouseTransform.new
  end

  def service
    @service ||= BenefitsClaims::Service.new(@icn)
  end
end
