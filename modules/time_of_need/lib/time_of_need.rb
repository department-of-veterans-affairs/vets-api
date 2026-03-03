# frozen_string_literal: true

require 'time_of_need/engine'

##
# Time of Need 40-4962 Module
#
# Handles burial scheduling requests submitted through VA.gov.
# Data flows: va.gov → vets-api → MuleSoft API → MDW → CaMEO (Salesforce)
#
module TimeOfNeed
  # The form_id
  FORM_ID = '40-4962'

  # The module path
  MODULE_PATH = 'modules/time_of_need'
end
