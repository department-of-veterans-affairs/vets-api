# frozen_string_literal: true

require 'sidekiq'
require './modules/vba_documents/app/models/vba_documents/git_items'

module VBADocuments
  class DeploymentsNotifier
    include Sidekiq::Worker

    def perform
      return unless Settings.vba_documents.slack.enabled
      result = nil
      begin
        VBADocuments::GitItems.populate
        result = VBADocuments::GitItems.notify
      rescue => e
        Rails.logger.error("Failed to notify of new VBA document deployments", e)
        result = e
      end
      result
    end
  end
end
# load('./modules/vba_documents/app/workers/vba_documents/deployments_notifier.rb')
# DeploymentsNotifier.perform_async
