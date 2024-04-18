# frozen_string_literal: true

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
  end
end
