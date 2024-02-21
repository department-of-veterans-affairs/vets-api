# frozen_string_literal: true


# This is the config the mobile team wrote:
# require 'lighthouse/benefits_documents/configuration'

# maybe move this to lib


require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'
# Do we need this?
# require 'lighthouse/service_exception'

module Services
  module Form526
    # Not sure if we need client base? I think we do
    class LighthouseDocumentStatusPollingService < Common::Client::Base
      configuration BenefitsDocuments::Configuration

      def self.call(*args)
        new(*args).call
      end

      def initialize(lighthouse_document_request_ids)
        @lighthouse_document_request_ids = lighthouse_document_request_ids
      end

      private

      def call
        get_document_status
      end

      def check_documents_status
        config.get_documents_status(@lighthouse_document_request_ids)
      end
    end
  end
end