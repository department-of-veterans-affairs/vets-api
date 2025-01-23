# frozen_string_literal: true

require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'
require 'evss/disability_compensation_form/service'
require 'evss/disability_compensation_form/non_breakered_service'

class EvssGeneratePdfProvider
  include GeneratePdfProvider

  def initialize(auth_headers, breakered: true)
    # both of these services implement `get_form526`
    @service = if breakered
                 EVSS::DisabilityCompensationForm::Service.new(auth_headers)
               else
                 EVSS::DisabilityCompensationForm::NonBreakeredService.new(auth_headers)
               end
  end

  def generate_526_pdf(form_content, _transaction_id = nil)
    @service.get_form526(form_content)
  end
end
