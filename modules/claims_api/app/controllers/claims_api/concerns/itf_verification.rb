# frozen_string_literal: true

module ClaimsApi
  module ItfVerification
    extend ActiveSupport::Concern

    included do
      def verify_itf
        active = itf_service.get_active('compensation')
        if !active['intent_to_file'] || active['intent_to_file'].expiration_date < Time.now.utc
          error = {
            errors: [
              {
                status: 422,
                details: 'Intent to File Expiration Date not valid, resubmit ITF.'
              }
            ]
          }
          render json: error, status: :unprocessable_entity
        end
      end

      def itf_service
        EVSS::IntentToFile::Service.new(target_veteran)
      end
    end
  end
end
