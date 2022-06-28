# frozen_string_literal: true

# Each row corresponds to one git 'item' as returned by the json in the following query:
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:BenefitsIntake%20repo:department-of-veterans-affairs/vets-api
module VBADocuments
  class GitItems < ApplicationRecord
    GIT_QUERY = 'https://api.github.com/search/issues'
    FORMS_PARAMS = { q: 'is:merged is:pr label:Forms repo:department-of-veterans-affairs/vets-api' }.freeze
    LABELS = %w[Forms].freeze

    validates :url, uniqueness: true

    module ClassMethods
      # notifies slack of all new deployments.  Returns the number notified on.
      def notify(label)
        slack_url = Settings.vba_documents.slack.deployment_notification_forms_url
        text = "The following new merges are now in #{label.underscore.titleize}:\n"
        models = []
        GitItems.where(notified: false, label: label).find_each do |model|
          url = model.url
          author = model.git_item['user']['login']
          title = model.git_item['title']
          text += "\tTitle: #{title}\n\t\tAuthor: #{author}\n\t\turl: #{url}\n"
          models << model
        end
        response = send_to_slack(text, slack_url) unless models.empty?
        if response&.success?
          models.each do |m|
            m.update(notified: true)
          end
        end
        models.length
      end

      def send_to_slack(text, url)
        Faraday.post(url, "{\"text\": \"#{text}\"}", 'Content-Type' => 'application/json')
      end

      def populate(label)
        response = query_git(FORMS_PARAMS)
        if response&.success?
          data = JSON(response.body)
          data['items'].each do |item|
            url = item['html_url']
            model = find_or_create_by(url: url)
            next if model.git_item

            model.git_item = item
            model.label = label
            saved = model.save
            Rails.logger.warn("Failed to save the data for url #{url}") unless saved
          end
        else
          Rails.logger.error("Failed to query git for #{label} merged in data")
        end
        GitItems.where(label: label).count
      end

      def query_git(params)
        Faraday.new(url: GIT_QUERY, params: params).get
      end
    end
    extend ClassMethods
  end
end

# load('./modules/vba_documents/app/models/vba_documents/git_items.rb')
# Sample query:
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:Forms%20repo:department-of-veterans-affairs/vets-api
#
