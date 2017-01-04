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

      VALID_STATUS_TYPES =  %w(IN_PROGRESS SUBMITTED REVOKED FAILED)

      attr_reader :client

      validates :form_type, :status, presence: true
      validates_inclusion_of :status, :in => VALID_STATUS_TYPES

      def params
        { get_in_flight_forms_request: { form_type: form_type, status: status } }
      end
    end
  end
end
