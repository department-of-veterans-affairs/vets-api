# frozen_string_literal: true

# Each row corresponds to one git 'item' as returned by the json in the following query:
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:BenefitsIntake%20repo:department-of-veterans-affairs/vets-api
module VBADocuments
  class GitItems < ApplicationRecord
    GIT_QUERY = 'https://api.github.com/search/issues'

    module ClassMethods
      # notifies slack of all new deployments.  Returns the number notified on.
      def notify
        slack_url = Settings.vba_documents.slack.notification_url
        text = "The following new merges are now in Benefits Intake:\n"
        models = []
        notify = false
        GitItems.all.find_each do |model|
          next if model.notified

          notify = true
          url = model.url
          author = model.git_item['user']['login']
          title = model.git_item['title']
          text += "\tTitle: #{title}\n\t\tAuthor: #{author}\n\t\turl: #{url}\n"
          models << model
        end
        response = send_to_slack(text, slack_url) if notify
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

      def populate
        response = query_git
        if response&.success?
          data = JSON(response.body)
          data['items'].each do |item|
            url = item['html_url']
            model = find_or_create_by(url: url)
            next if model.git_item

            model.git_item = item
            saved = model.save
            Rails.logger.warn("Failed to save the data for url #{url}") unless saved
          end
        else
          Rails.logger.error('Failed to query git for benefits intake merged in data')
        end
        GitItems.count
      end

      def query_git
        params = { q: 'is:merged is:pr label:BenefitsIntake repo:department-of-veterans-affairs/vets-api' }
        Faraday.new(url: GIT_QUERY, params: params).get
      end
    end
    extend ClassMethods
  end
end
# load('./modules/vba_documents/app/models/vba_documents/git_items.rb')
#  b = DeploymentStatus.find_or_create_by(url: url)
#
# https://api.github.com/search/issues?q=is:merged%20is:pr%20label:BenefitsIntake%20repo:department-of-veterans-affairs/vets-api
#
