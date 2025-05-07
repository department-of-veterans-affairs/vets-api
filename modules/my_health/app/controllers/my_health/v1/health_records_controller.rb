# frozen_string_literal: true

module MyHealth
  module V1
    class HealthRecordsController < BBController
      include MyHealth::AALClientConcerns

      def refresh
        resource = client.get_extract_status

        render json: ExtractStatusSerializer.new(resource.data, { meta: resource.metadata })
      end

      def eligible_data_classes
        resource = client.get_eligible_data_classes

        render json: EligibleDataClassesSerializer.new(resource.data, { meta: resource.metadata })
      end

      def create
        client.post_generate(params.permit(:from_date, :to_date, data_classes: []))

        head :accepted
      end

      def optin
        handle_aal_action('Opt back into electronic sharing with community providers') do
          client.post_opt_in
        end
      end

      def optout
        handle_aal_action('Opt out of electronic sharing with community providers') do
          client.post_opt_out
        end
      end

      def status
        resource = client.get_status
        render json: resource
      end

      def product
        :mr
      end

      private

      def handle_aal_action(action_description)
        response = yield
        log_aal_action(action_description, 1)
        response
      rescue => e
        log_aal_action(action_description, 0)
        raise e
      end

      def log_aal_action(action, status)
        aal_client.create_aal(
          activity_type: 'VA Health Record',
          action:,
          performer_type: 'Self',
          status:
        )
      end
    end
  end
end
