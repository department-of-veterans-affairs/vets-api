# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'

module BenefitsDocuments
  module Form526
    class DocumentsStatusPollingService < Common::Client::Base
      configuration BenefitsDocuments::Configuration

      def self.call(args)
        new(args).call
      end

      def initialize(lighthouse_document_request_ids)
        @lighthouse_document_request_ids = lighthouse_document_request_ids
        super()
      end

      def call
        check_documents_status
      end

      private

      def check_documents_status
        config.get_documents_status(@lighthouse_document_request_ids)
      end
    end
  end
end
