# frozen_string_literal: true

module MyHealth
  module V1
    module MedicalRecords
      class BbmiNotificationController < MrController
        # Retrieves the BBMI notification setting
        # @return [JSON] BBMI notification setting
        def status
          resource = bb_client.get_bbmi_notification_setting
          render json: resource
        end
      end
    end
  end
end
