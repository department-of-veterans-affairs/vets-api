# frozen_string_literal: true

require 'notary'

module VeteranVerification
  module V1
    class ServiceHistoryController < ApplicationController
      include ActionController::MimeResponds

      NOTARY = VeteranVerification::Notary.new(Settings.vet_verification.key_path)

      before_action { authorize :va_profile, :access? }
      before_action { permit_scopes %w[service_history.read] }

      def index
        response = ServiceHistoryEpisode.for_user(@current_user)

        serialized = ActiveModelSerializers::SerializableResource.new(
          response,
          each_serializer: VeteranVerification::ServiceHistorySerializer
        )

        respond_to do |format|
          format.json { render json: serialized.to_json }
          format.jwt { render body: NOTARY.sign(serialized.serializable_hash) }
        end
      end
    end
  end
end
