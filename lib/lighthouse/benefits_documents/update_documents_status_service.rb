# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'

module BenefitsDocuments
  class DocumentsStatusPollingService < Common::Client::Base
    configuration BenefitsDocuments::Configuration

    def self.call(args)
      new(args).check_documents_status
    end

    def initialize(document_request_ids)
      @document_request_ids = document_request_ids
      super()
    end

    def check_documents_status
      fetch_documents_status
    end

    private

    def fetch_documents_status
      config.get_documents_status(@document_request_ids)
    end
  end
end
