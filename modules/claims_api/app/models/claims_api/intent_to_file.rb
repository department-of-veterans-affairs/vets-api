# frozen_string_literal: true

module ClaimsApi
  class IntentToFile
    ITF_TYPES = {
      'compensation' => 'C',
      'burial' => 'S',
      'pension' => 'P'
    }.freeze

    SUBMITTER_CODE = 'VETS.GOV'
  end
end
