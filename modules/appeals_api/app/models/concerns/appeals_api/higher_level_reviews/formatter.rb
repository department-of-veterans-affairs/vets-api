# frozen_string_literal: true

module AppealsApi
  module HigherLevelReviews
    class Formatter
      def initialize(higher_level_review)
        @higher_level_review = higher_level_review
      end

      def birth_date
        AppealsApi::HigherLevelReview::Date.new(
          higher_level_review.auth_headers.dig('X-VA-Birth-Date')
        )
      end

      def date_signed
        AppealsApi::HigherLevelReview::Date.new(veterans_local_time)
      end

      def contestable_issues
        issues = higher_level_review.form_data.dig('included') || []

        issues.map do |issue|
          AppealsApi::HigherLevelReview::ContestableIssue.new(issue)
        end
      end

      private

      attr_accessor :higher_level_review

      def version
        higher_level_review.pdf_version
      end

      def veterans_local_time
        timezone = higher_level_review.form_data&.dig(
          'data', 'attributes', 'veteran', 'timezone'
        ).presence&.strip

        if timezone
          Time.now.in_time_zone(timezone)
        else
          Time.now.utc
        end
      end
    end
  end
end
