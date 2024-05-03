# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class NewDependentSerializer
      include JSONAPI::Serializer

      set_type :dependent
      attribute :submit_form_job_id

      def initialize(dependent_info)
        resource = NewDependentStruct.new(SecureRandom.uuid, dependent_info[:submit_form_job_id])
        super(resource, {})
      end
    end
    NewDependentStruct = Struct.new(:id, :submit_form_job_id)
  end
end
