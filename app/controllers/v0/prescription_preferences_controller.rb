# frozen_string_literal: true

module V0
  class PrescriptionPreferencesController < RxController
    def show
      resource = client.get_preferences
      render json: resource,
             serializer: PrescriptionPreferenceSerializer
    end

    def update
      resource = client.post_preferences(params)
      render json: resource,
             serializer: PrescriptionPreferenceSerializer
    end
  end
end
