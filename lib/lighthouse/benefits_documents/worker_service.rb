# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/benefits_documents/configuration'
require 'lighthouse/service_exception'

module BenefitsDocuments
  class WorkerService < Common::Client::Base
    configuration BenefitsDocuments::Configuration
    STATSD_KEY_PREFIX = 'api.benefits_documents'
    STATSD_UPLOAD_LATENCY = 'lighthouse.api.benefits.documents.latency'

    def upload_document(file_body, lighthouse_document)
      config.post(file_body, lighthouse_document) # returns upload response which includes requestId
    end
  end
end
