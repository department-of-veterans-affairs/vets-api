# frozen_string_literal: true
class FeedbackService
  def submit_feedback(title, message, category, email, url)
    message = "Feedback submitted from #{email} via #{url}:\n> #{message}"
    labels = %w(UserVoice)
    labels << category
    client.create_issue(Settings.github.feedback_repo, title, message, options = {labels: labels})
  end

  private

  def client
    @client ||= Octokit::Client.new(access_token: Settings.github.access_token)
  end
end
