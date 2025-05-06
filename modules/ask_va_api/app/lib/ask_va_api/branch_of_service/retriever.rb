# frozen_string_literal: true

require 'brd/brd'

module AskVAApi
  module BranchOfService
    class Retriever < BaseRetriever
      attr_reader :brd

      def initialize(**args)
        super(**args)
        @brd = ClaimsApi::BRD.new
      end

      private

      def fetch_data
        if user_mock_data
          I18n.t('ask_va_api.branch_of_service')
        else
          brd.service_branches
        end
      end
    end
  end
end
