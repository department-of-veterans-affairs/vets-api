# frozen_string_literal: true

require 'sidekiq'
require 'sidekiq/monitored_worker'

require 'pdf_generator_service/pdf_client'

module ClaimsApi
  module V2
    class DisabilityCompensationDockerContainerUpload
      include Sidekiq::Job
      include SentryLogging
      include Sidekiq::MonitoredWorker

      def perform()
      end
    end
  end
end