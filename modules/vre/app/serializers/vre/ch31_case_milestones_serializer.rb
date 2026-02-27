# frozen_string_literal: true

module VRE
  class Ch31CaseMilestonesSerializer
    include JSONAPI::Serializer

    set_id { '' }

    attributes :res_case_id,
               :response_message
  end
end
