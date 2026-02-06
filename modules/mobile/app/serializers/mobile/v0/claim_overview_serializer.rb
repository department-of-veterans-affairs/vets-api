# frozen_string_literal: true

require 'jsonapi/serializer'

module Mobile
  module V0
    class ClaimOverviewSerializer
      include JSONAPI::Serializer
      attributes :subtype, :completed, :date_filed, :updated_at, :display_title, :decision_letter_sent, :phase,
                 :documents_needed, :development_letter_sent, :claim_type_code, :claim_type_base, :provider

      def self.record_hash(record, fieldset, includes = {}, params = {})
        h = super
        h[:type] = record.type
        h
      end
    end
  end
end
