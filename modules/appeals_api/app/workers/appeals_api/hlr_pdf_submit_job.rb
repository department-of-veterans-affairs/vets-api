# frozen_string_literal: true

require 'sidekiq'

module AppealsApi
  class HlrPdfSubmitJob
    include Sidekiq::Worker

    def perform(higher_level_review_id)
      higher_level_review = AppealsApi::HigherLevelReview.find(higher_level_review_id)
      veteran = build_veteran(higher_level_review)
      AppealsApi::HlrPdfConstructor.new(target_veteran)
    end

    def build_veteran(higher_level_review)
      form_data = higher_level_review.form_data
      OpenStruct.new(
        first_name: form_data[:first_name],
        middle_name: form_data[:middle_name],
        last_name: form_data[:last_name],
        ssn: auth_headers[:ssn],
        birth_date: form_data[:birth_date],
        address: form_data[:address],
        address_2: form_data[:address_2],
        city: form_data[:city],
        state: form_data[:state],
        country: form_data[:country],
        zip: form_data[:zip],
        zip_last_4: form_data[:zip_last_4],
        benefit_type: form_data[:benefit_type],
        same_office: form_data[:same_office],
        informal_conference: form_data[:informal_conference],
        issues: form_data[:issues]
      )
    end
  end
end
