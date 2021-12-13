# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class ConfirmationMailerJob
      include Sidekiq::Worker

      def perform(recipient, template_name)
        SubmissionMailer.build(recipient, template_name).deliver
      end
    end
  end
end
