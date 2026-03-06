# frozen_string_literal: true

require 'bb/client'

module MyHealth
  module V1
    class VhieSharingController < ApplicationController
      include MyHealth::MHVControllerConcerns
      include MyHealth::AALClientConcerns
      service_tag 'mhv-medical-records'

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

      protected

      def client
        @client ||= BB::Client.new(session: { user_id: current_user.mhv_correlation_id })
      end

      def authorize
        raise_access_denied unless current_user.authorize(:mhv_medical_records, :access?)
      end

      def raise_access_denied
        raise Common::Exceptions::Forbidden, detail: 'You do not have access to medical records'
      end

      def product
        :mr
      end
    end
  end
end
