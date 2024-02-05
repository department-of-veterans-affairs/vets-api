# frozen_string_literal: true

require 'brd/brd'

module ClaimsApi
  module V2
    module DisabilityCompensationSharedServiceModule
      def brd
        @brd ||= BRD.new
      end

      def retrieve_separation_locations
        @intake_sites ||= brd.intake_sites
      end

      def brd_service_branch_names
        @brd_service_branch_names ||= brd_service_branches&.pluck(:description)
      end

      def brd_service_branches
        @brd_service_branches ||= brd.service_branches
      end

      def valid_countries
        @valid_countries ||= brd.countries
      end

      def brd_classification_ids
        @brd_classification_ids ||= brd_disabilities&.pluck(:id)
      end

      def brd_disabilities
        @brd_disabilities ||= brd.disabilities
      end
    end
  end
end
