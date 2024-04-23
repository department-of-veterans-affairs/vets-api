# frozen_string_literal: true

require 'faraday'
require 'json'

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    # TODO: Add ARP to Datadog Service Catalog #77004
    #   https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/77004
    # It will be the dd-service property for your application here:
    #   https://github.com/department-of-veterans-affairs/vets-api/tree/master/datadog-service-catalog
    service_tag 'accredited-representative-portal'
    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_feature_enabled!

    def form21a
      conn = Faraday.new(url: 'http://localhost:5000/api/v1/accreditation/applications/form21a')
      response = conn.post do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = request.raw_post
      end

      if response.body.present?
        begin
          json_response = JSON.parse(response.body)
          render json: json_response, status: response.status
        rescue JSON::ParserError => e
          doc = Nokogiri::HTML(e.message)
          h2_text = doc.at('h2').text rescue e.message
          render json: { errors: h2_text }, status: 500
        end
      else
        render status: 204
      end
    end

    private

    def verify_feature_enabled!
      return if Flipper.enabled?(:accredited_representative_portal_api)

      raise Common::Exceptions::RoutingError, params[:path]
    end
  end
end
