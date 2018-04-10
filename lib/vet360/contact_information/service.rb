# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      def get_person
        with_monitoring do
          # TODO - guard clause in case there is no vet360_id
          raw_response = perform(:get, @user.vet360_id)
byebug
          Vet360::ContactInformation::PersonResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def post_email(request_body)
        post_or_put_email(:post, request_body)
      end

      def put_email(request_body)
        post_or_put_email(:put, request_body)
      end

      private

      def post_or_put_email(method, request_body)
        with_monitoring do
          json = perform(method, "cuf/person/contact-information/v1/emails", request_body).body
          Vet360::ContactInformation::EmailTxResponse.new(json.status, json)
        end
      rescue StandardError => e
        handle_error(e)
      end

    end
  end
end
