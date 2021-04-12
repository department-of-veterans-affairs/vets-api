# frozen_string_literal: true

require 'sidekiq'
require './modules/vba_documents/app/models/vba_documents/git_items'

module VBADocuments
  class DeploymentsNotifier
    include Sidekiq::Worker

    VALID_LABELS = GitItems::LABELS + [nil]

    def perform(label = nil)
      return unless Settings.vba_documents.slack.enabled
      raise ArgumentError, "Label #{label} is invalid. Use #{VALID_LABELS}}" unless VALID_LABELS.include?(label)

      result = []
      begin
        if label.nil?
          GitItems::LABELS.each do |l|
            result << DeploymentsNotifier.perform_async(l)
          end
        else
          GitItems.populate(label)
          result << GitItems.notify(label)
        end
      rescue => e
        Rails.logger.error("Failed to notify for #{label} deployments", e)
        result << e
      end
      result
    end
  end
end
# load('./modules/vba_documents/app/workers/vba_documents/deployments_notifier.rb')
# DeploymentsNotifier.perform_async
