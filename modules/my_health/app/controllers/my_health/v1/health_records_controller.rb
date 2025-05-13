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
        handle_aal('VA Health Record', 'Opt back into electronic sharing with community providers') do
          client.post_opt_in
        end
      end

      def optout
        handle_aal('VA Health Record', 'Opt out of electronic sharing with community providers') do
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
    end
  end
end
