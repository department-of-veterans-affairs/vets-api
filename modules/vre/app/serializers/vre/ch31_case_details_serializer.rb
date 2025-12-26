# frozen_string_literal: true

module VRE
  class Ch31CaseDetailsSerializer
    include JSONAPI::Serializer

    set_id { '' }

    attributes :res_case_id,
               :is_transfered_to_cwnrs,
               :external_status
  end
end
