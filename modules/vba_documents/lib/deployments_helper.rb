# frozen_string_literal: true

#module DeploymentsHelper shared by forms and benefits intake API
module VBADocuments
  module VAForms
    module DeploymentsHelper

      def self.extended(base)
        unless(base.constants.include?(:GIT_URL) && base.constants.include?(:GIT_PARAMS))
          msg = "Define the constant GIT_URL and GIT_PARAMS before extending this module!"
          raise NameError.new msg
        end
      end

      def notify(slack_url)
        text = "The following new merges are now in Benefits Intake:\n"
        models = []
        where(notified: false).each do |model|
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
        count
      end

      def query_git
        Faraday.new(url: self::GIT_URL, params: self::GIT_PARAMS).get
      end
    end
  end
end