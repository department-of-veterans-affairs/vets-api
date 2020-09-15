# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class ConfirmationMailerJob
      include Sidekiq::Worker

      def perform(recipient)
        SubmissionMailer.build(recipient).deliver
      end
    end
  end
end
