# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class ClaimOverviewSerializer
      include JSONAPI::Serializer
      attributes :subtype, :completed, :date_filed, :updated_at

      def self.record_hash(record, fieldset, includes_list, params = {})
        h = super
        h[:type] = record.type
        h
      end
    end
  end
end
