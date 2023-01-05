# frozen_string_literal: true

module ClaimsApi
  module V2
    class IntentToFile < ClaimsApi::IntentToFile
      ITF_TYPES_TO_BGS_TYPES = {
        'compensation' => 'C',
        'survivor' => 'S',
        'pension' => 'P'
      }.freeze
    end
  end
end
