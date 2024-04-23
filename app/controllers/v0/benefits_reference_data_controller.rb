# frozen_string_literal: true

require 'lighthouse/benefits_reference_data/service'
module V0
  class BenefitsReferenceDataController < ApplicationController
    include ActionController::Serialization
    service_tag 'disability-application'

    skip_before_action :authenticate 

    def get_data
      render json: benefits_reference_data_service
        .get_data(path: params[:path], params: request.query_parameters).body
    end

    private

    def benefits_reference_data_service
      BenefitsReferenceData::Service.new
    end
  end
end
