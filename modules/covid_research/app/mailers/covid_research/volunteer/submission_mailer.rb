# frozen_string_literal: true

module CovidResearch
  module Volunteer
    class SubmissionMailer < ApplicationMailer
      SIGNUP_SUBJECT = 'VA coronavirus research volunteer list'

      def build(recipient)
        body = ERB.new(template).result(binding)

        mail(
          to: recipient,
          subject: SIGNUP_SUBJECT,
          content_type: 'text/html',
          body: body
        )
      end

      private

      def template
        File.read template_path
      end

      def template_path
        CovidResearch::Engine.root.join('app', 'views', 'covid_research', 'volunteer', 'signup_confirmation.html.erb')
      end
    end
  end
end
