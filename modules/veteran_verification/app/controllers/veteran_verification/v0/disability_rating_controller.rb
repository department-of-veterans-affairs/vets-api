# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'
require_dependency 'notary'

module VeteranVerification
  module V0
    class DisabilityRatingController < ApplicationController
      include ActionController::MimeResponds

      NOTARY = VeteranVerification::Notary.new(Settings.vet_verification.key_path)

      before_action { authorize :evss, :access? }
      before_action { permit_scopes %w[disability_rating.read] }

      def index
        disabilities_response = service.get_rated_disabilities
        serialized = ActiveModelSerializers::SerializableResource.new(
          disabilities_response.rated_disabilities,
          each_serializer: VeteranVerification::DisabilityRatingSerializer
        )

        respond_to do |format|
          format.json { render json: serialized.to_json }
          format.jwt { render body: NOTARY.sign(serialized.serializable_hash) }
        end
      end

      private

      def service
        EVSS::DisabilityCompensationForm::Service.new(auth_headers)
      end

      def auth_headers
        headers = EVSS::DisabilityCompensationAuthHeaders.new(@current_user)
        headers.add_headers(EVSS::AuthHeaders.new(@current_user).to_h)
      end
    end
  end
end
