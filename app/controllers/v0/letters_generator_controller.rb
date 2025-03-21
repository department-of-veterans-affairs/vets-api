# frozen_string_literal: true

require 'lighthouse/letters_generator/service'
require 'lighthouse/letters_generator/service_error'

module V0
  class LettersGeneratorController < ApplicationController
    service_tag 'letters'
    before_action { authorize :lighthouse, :access? }
    before_action :validate_letter_type, only: %i[download]

    Sentry.set_tags(team: 'benefits-claim-appeal-status', feature: 'letters-generator')
    DOWNLOAD_PARAMS = %i[
      id
      format
      military_service
      service_connected_disabilities
      service_connected_evaluation
      non_service_connected_pension
      monthly_award
      unemployable
      special_monthly_compensation
      adapted_housing
      chapter35_eligibility
      death_result_of_disability
      survivors_award
      letters_generator
    ].freeze

    def index
      response = service.get_eligible_letter_types(@current_user.icn)
      render json: response
    end

    def download
      icns = { icn: @current_user.icn }

      response = service.download_letter(icns, params[:id], letter_options)
      send_data response, filename: "#{params[:id]}.pdf", type: 'application/pdf', disposition: 'attachment'
    end

    def beneficiary
      response = service.get_benefit_information(@current_user.icn)
      render json: response
    end

    private

    def download_params
      params.permit(DOWNLOAD_PARAMS)
    end

    def validate_letter_type
      unless service.valid_type?(params[:id])
        detail = "Letter type of #{params[:id]} is not one of the expected options"
        raise Common::Exceptions::BadRequest.new({ detail:, source: self.class.name })
      end
    end

    def service
      @service ||= Lighthouse::LettersGenerator::Service.new
    end

    def letter_options
      download_params.to_h
                     .except('id')
                     .transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
                     .transform_keys { |k| k.camelize(:lower) }
    end
  end
end
