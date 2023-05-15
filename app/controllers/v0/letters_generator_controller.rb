# frozen_string_literal: true

require 'lighthouse/letters_generator/service'
require 'lighthouse/letters_generator/service_error'

module V0
  class LettersGeneratorController < ApplicationController
    before_action { authorize :lighthouse, :access? }
    Raven.tags_context(team: 'benefits-claim-appeal-status', feature: 'letters-generator')
    DOWNLOAD_PARAMS = %i[
      id
      format
      militaryService
      serviceConnectedDisabilities
      serviceConnectedEvaluation
      nonServiceConnectedPension
      monthlyAward
      unemployable
      specialMonthlyCompensation
      adaptedHousing
      chapter35Eligibility
      deathResultOfDisability
      survivorsAward
    ].freeze

    def index
      response = service.get_eligible_letter_types(@current_user.icn)
      render json: response
    end

    def download
      permitted_params = params.permit(DOWNLOAD_PARAMS)
      letter_options =
        permitted_params.to_h
                        .select { |_, v| v == 'true' }
                        .transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
      response = service.download_letter(@current_user.icn, params[:id], letter_options)
      send_data response,
                filename: "#{params[:id]}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    end

    def beneficiary
      response = service.get_benefit_information(@current_user.icn)
      render json: response
    end

    private

    def service
      @service ||= Lighthouse::LettersGenerator::Service.new
    end
  end
end
