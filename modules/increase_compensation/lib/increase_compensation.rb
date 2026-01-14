# frozen_string_literal: true

require 'increase_compensation/engine'

module IncreaseCompensation
  # APPLICATION FOR INCREASED COMPENSATION BASED ON UNEMPLOYABILITY Form ID
  FORM_ID = '21-8940V1'

  # 21-8940V1 is used to avoid collisions with a older version of thr form still in the backend.
  # Remove the 'v1' here to be used with external tools and expectations
  FORM_REAL_ID = '21-8940'

  # The module path
  MODULE_PATH = 'modules/increase_compensation'

  # The version label appended to the form type IBM expects (month/year).
  # @return [String]
  FORM_VERSION = 'SEP 2024'

  # The IBM-visible form type string (includes the version label).
  # @return [String]
  FORM_TYPE_LABEL = "VA FORM #{FORM_REAL_ID}, #{FORM_VERSION}".freeze

  # API Version 0
  module V0
  end

  # BenefitsIntake
  # @see lib/lighthouse/benefits_intake
  module BenefitsIntake
  end

  # PdfFill
  # @see lib/pdf_fill
  module PdfFill
  end
end
