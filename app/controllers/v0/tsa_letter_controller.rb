# frozen_string_literal: true

require 'claims_evidence_api/service/search'

module V0
  class TsaLetterController < ApplicationController
    service_tag 'tsa_letter'

    def index
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
      render(json: {uuid: latest_uuid, version: latest_version})
    end

    # service = ClaimsEvidenceApi::Service::Search.new
    # filters = { subject: ['VETS Safe Travel Outreach Letter'] }
    # folder_identifier = "VETERAN:ICN:#{user icn}"
    # service.folder_identifier = folder_identifier
    # start_time = Time.now
    # response = service.find(filters:)
    # end_time = Time.now
    # elapsed = end_time - start_time
    # puts "Elapsed: #{elapsed}"

    # require 'claims_evidence_api/service/files'
    # service = ClaimsEvidenceApi::Service::Files.new
    # uuid = 'c75438b4-47f8-44d3-9e35-798158591456' # pulled from search response
    # version = '920debba-cc65-479c-ab47-db9b2a5cd95f' # from search response

    def show
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
