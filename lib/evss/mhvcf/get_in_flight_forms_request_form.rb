# frozen_string_literal: true
require 'active_model'
require 'common/models/attribute_types/utc_time'

module EVSS
  module MHVCF
    class GetInFlightFormsRequestForm
      extend ActiveModel::Naming
      include ActiveModel::Validations
      include Virtus.model(nullify_blank: true)
      attribute :form_type, String
      attribute :status, String

      VALID_FORM_TYPES = %w(10-0525 10-5345A-MHV 10-0485 10-0484 10-0525A).freeze
      VALID_STATUS_TYPES = %w(IN_PROGRESS SUBMITTED REVOKED FAILED).freeze

      validates_inclusion_of :form_type, in: VALID_FORM_TYPES, allow_blank: true
      validates_inclusion_of :status, in: VALID_STATUS_TYPES, allow_blank: true

      def params
        { form_type: form_type, status: status }.compact
      end
    end
  end
end
