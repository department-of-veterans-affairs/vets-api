# frozen_string_literal: true

require 'unique_user_events'

module MyHealth
  module V1
    class VitalsController < MRController
      def index
        resource = client.list_vitals(params[:from], params[:to])

        # Log unique user events for vitals accessed
        UniqueUserEvents.log_events(
          user: current_user,
          event_names: [
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_ACCESSED,
            UniqueUserEvents::EventRegistry::MEDICAL_RECORDS_VITALS_ACCESSED
          ]
        )

        render_resource resource
      end
    end
  end
end
