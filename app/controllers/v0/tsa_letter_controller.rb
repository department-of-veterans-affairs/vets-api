# frozen_string_literal: true

require 'claims_evidence_api/service/search'
require 'claims_evidence_api/service/files'

module V0
  class TsaLetterController < ApplicationController
    service_tag 'tsa_letter'
    before_action { authorize :tsa_letter, :access? }

    ERROR_MAP = {
      401 => Common::Exceptions::Unauthorized,
      500 => Common::Exceptions::ExternalServerInternalServerError,
      501 => Common::Exceptions::NotImplemented
    }.freeze
    # 403 indicates that the API doesn't know the user.
    # 400 is a bad request, but it's unclear why this happens
    NONBLOCKING_STATUSES = [400, 403].freeze

    def show
      search_service = ClaimsEvidenceApi::Service::Search.new
      filters = { subject: ['VETS Safe Travel Outreach Letter'] }
      folder_identifier = "VETERAN:ICN:#{current_user.icn}"
      search_service.folder_identifier = folder_identifier
      response = search_service.find(filters:)
      files = response.body['files']
      serialized = most_recent_letter(files)
      render(json: serialized)
    rescue Common::Client::Errors::ClientError => e
      handle_error(e)
    end

    def download
      download_service = ClaimsEvidenceApi::Service::Files.new
      letter_response = download_service.download(params[:id], params[:version_id])
      send_data(
        letter_response.body,
        type: 'application/pdf',
        filename: 'VETS Safe Travel Outreach Letter.pdf'
      )
    end

    private

    def most_recent_letter(files)
      return { data: nil } if files.blank?

      latest = files.max do |a, b|
        a_time = DateTime.parse(a.dig('currentVersion', 'providerData', 'modifiedDateTime'))
        b_time = DateTime.parse(b.dig('currentVersion', 'providerData', 'modifiedDateTime'))
        a_time <=> b_time
      end
      document_id = latest['uuid']
      document_version = latest['currentVersionUuid']
      modified_datetime = latest.dig('currentVersion', 'providerData', 'modifiedDateTime')
      tsa_letter_metadata = OpenStruct.new(document_id:, document_version:, modified_datetime:)
      TsaLetterSerializer.new(tsa_letter_metadata)
    rescue Date::Error
      datetimes = files.map { |file| file.dig('currentVersion', 'providerData', 'modifiedDateTime') }
      raise Common::Exceptions::UnprocessableEntity,
            detail: "Invalid datetime format found in TSA letters data: #{datetimes.join(', ')}",
            source: self.class.name
    end

    def handle_error(error)
      known_errors = ERROR_MAP.keys + NONBLOCKING_STATUSES
      raise error unless error.respond_to?(:status) && error.status.in?(known_errors)

      if error.status.in?(ERROR_MAP.keys)
        error_class = ERROR_MAP[error.status]
        raise error_class
      end

      Rails.logger.info('TSA Letter Error',
                        error_status: error.status,
                        user_account_id: current_user.user_account_uuid)
      render(json: { data: nil }) and return
    end
  end
end
