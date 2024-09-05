# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class EnrollmentStatus < Common::Resource
      attribute :id, Types::String
      attribute :application_date, Types::String.optional.default(nil)
      attribute :enrollment_date, Types::String.optional.default(nil)
      attribute :preferred_facility, Types::String.optional.default(nil)
      attribute :parsed_status, Types::String.optional.default(nil)
      attribute :primary_eligibility, Types::String.optional.default(nil)
      attribute :can_submit_financial_info, Types::Bool.optional.default(nil)

      def status
        case parsed_status
        when :enrolled
          'enrolled'
        when :pending_mt, :pending_other
          'pending'
        else
          'other'
        end
      end
    end
  end
end
