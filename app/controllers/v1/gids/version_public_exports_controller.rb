# frozen_string_literal: true

require 'gi/client'

module V1
  module GIDS
    class VersionPublicExportsController < GIDSController
      def show
        client = ::GI::Client.new
        client_response = client.get_public_export_v1(scrubbed_params)
        if client_response.status == 200
          send_data(
            client_response.body,
            content_type: client_response.response_headers['Content-Type'],
            disposition: client_response.response_headers['Content-Disposition']
          )
        else
          render client_response
        end
      end
    end
  end
end
