# frozen_string_literal: true

require 'claims_evidence_api/service/search'

module V0
  class TsaLetterController < ApplicationController
    service_tag 'tsa_letter'

    # x figure out routing
    # "record" 404 vcr cassette
    # serializer
    # finish specs
    # add spec for empty response
    # make sorting safer
    # match on body
    # turn off feature flag in staging

    def show
      search_service = ClaimsEvidenceApi::Service::Search.new
      filters = { subject: ['VETS Safe Travel Outreach Letter'] }
      folder_identifier = "VETERAN:ICN:#{current_user.icn}"
      search_service.folder_identifier = folder_identifier
      response = search_service.find(filters:)
      files = response.body['files']
      latest = files.max do |a, b|
        # this needs to be more secure
        a_time = DateTime.parse(a['currentVersion']['systemData']['uploadedDateTime'])
        b_time = DateTime.parse(b['currentVersion']['systemData']['uploadedDateTime'])
        a_time <=> b_time
      end
      latest_uuid = latest['uuid']
      latest_version = latest['currentVersionUuid']
      upload_date = latest['currentVersion']['systemData']['uploadedDateTime']
      render(json: {uuid: latest_uuid, version: latest_version, upload_date:})
    rescue => e
      if e.respond_to?(:status) && e.status == 404
        raise Common::Exceptions::RecordNotFound, current_user.user_account_uuid
      else
        raise e
      end
    end

    def download
      send_data(
        service.get_tsa_letter(params[:id]),
        type: 'application/pdf',
        filename: 'VETS Safe Travel Outreach Letter.pdf'
      )
    end

    private

    def service
      Efolder::Service.new(@current_user)
    end
  end
end
