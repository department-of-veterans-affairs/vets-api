# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class NewDependentSerializer
      include JSONAPI::Serializer

      set_type :dependent
      attribute :submit_form_job_id
    end
  end
end
