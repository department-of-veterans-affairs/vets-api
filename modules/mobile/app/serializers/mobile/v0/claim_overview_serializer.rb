# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class ClaimOverviewSerializer
      include JSONAPI::Serializer
      attributes :subtype, :completed, :date_filed, :updated_at, :display_title

      def self.record_hash(record, fieldset, includes = {}, params = {})
        h = super
        h[:type] = record.type
        h
      end
    end
  end
end
