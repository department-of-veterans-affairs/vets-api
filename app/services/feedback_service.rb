# frozen_string_literal: true
class FeedbackService

  ACCESS_TOKEN = Settings.github.access_token
  FEEDBACK_REPO = Settings.github.feedback_repo

  def submit_feedback(title, message, category, email, url)
    message = "Feedback submitted from #{email} via #{url}:\n> #{message}"
    labels = %w(UserVoice)
    labels << category
    client.create_issue(FEEDBACK_REPO, title, message, options = {labels: labels})
  end

  private

  def client
    @client ||= Octokit::Client.new(access_token: ACCESS_TOKEN)
  end
end
