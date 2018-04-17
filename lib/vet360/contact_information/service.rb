# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      def get_person
        with_monitoring do
          # TODO: guard clause in case there is no vet360_id
          raw_response = perform(:get, @user.vet360_id)

          Vet360::ContactInformation::PersonResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def get_email_transaction_status(transaction_id)
        with_monitoring do
          route = "#{@user.vet360_id}/emails/status/#{transaction_id}"
          raw_response = perform(:get, route)

          Vet360::ContactInformation::TransactionStatusResponse.new(raw_response.status, raw_response)
        end
      end
    end
  end
end
