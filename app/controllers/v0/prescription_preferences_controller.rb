# frozen_string_literal: true
module V0
  class PrescriptionPreferencesController < RxController
    def show
      resource = client.get_preferences
      render json: resource,
             serializer: PrescriptionPreferenceSerializer
    end

    def update
      require_params
      client.post_preferences(params)
      render nothing: true, status: :accepted
    end

    private

    def require_params
      params.require(:email_address)
      params.require(:rx_flag)
    end
  end
end
