# frozen_string_literal: true

require 'notary'

module VeteranVerification
  module V0
    class DisabilityRatingController < ApplicationController
      include ActionController::MimeResponds

      NOTARY = VeteranVerification::Notary.new(Settings.vet_verification.key_path)

      before_action { permit_scopes %w[disability_rating.read] }

      def index
        response = DisabilityRating.for_user(@current_user)
        serialized = ActiveModelSerializers::SerializableResource.new(
          response,
          each_serializer: VeteranVerification::DisabilityRatingSerializer
        )
        respond_to do |format|
          format.json { render json: serialized.to_json }
          format.jwt { render body: NOTARY.sign(serialized.serializable_hash) }
        end
      end
    end
  end
end
