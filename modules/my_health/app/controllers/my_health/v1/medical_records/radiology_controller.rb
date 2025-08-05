# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class RadiologyController < MRController
        def index
          resource = bb_client.list_radiology
          render json: resource.to_json
        end
      end
    end
  end
end
