# frozen_string_literal: true

module V0
  class VocationalReadinessEmploymentFormController < ApplicationController
    def create
      claim = SavedClaim::CaregiversAssistanceClaim.new(form: vocational_readiness_employment_form)

      unless claim.save?

      end

      render json: claim.parsed_form
    end

    # {
    #   "vocational_readiness_employment_form" => {
    #     "education_level" => "BACHELORS",
    #     "is_moving" => true,
    #     "new_address" => {
    #       "country_name" => "USA", "address_line1" => "9417 Princess Palm", "city" => "Tampa", "state_code" => "FL", "zip_code" => "33928"
    #     },
    #     "veteran_address" => {
    #       "country_name" => "USA", "address_line1" => "9417 Princess Palm", "city" => "Tampa", "state_code" => "FL", "zip_code" => "33928"
    #     },
    #     "main_phone" => "5555555555",
    #     "email_address" => "cohnjesse@gmail.xom",
    #     "veteran_information" => {
    #       "full_name" => {
    #         "first" => "JERRY", "middle" => "M", "last" => "BROOKS"
    #       }, "dob" => "1947-09-25"
    #     }
    #   }
    # }

    private

    def employment_readiness_params
      params.permit(vocational_readiness_employment_form: {})
    end

  end
end