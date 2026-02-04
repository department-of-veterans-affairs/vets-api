# frozen_string_literal: true

require 'lighthouse/benefits_documents/service'

module DisabilityCompensation
  ##
  # TODO: Describe how to set settings for Benefits Claims API and
  # Benefits Documents API. This includes `host` and `access_token` for both.
  #
  module DownloadClaimDocuments
    class << self
      def perform(claim_id:, icn:) # rubocop:disable Metrics/MethodLength
        profile_service = MPI::Service.new
        profile = fetch_profile(profile_service, icn)

        claims_service = BenefitsClaims::Service.new(profile.icn)
        documents_service = BenefitsDocuments::Service.new(:__UNUSED__)

        claim = fetch_claim(claims_service, claim_id)
        claim_documents = get_claim_documents(claim)

        vbms_document_uuids = fetch_vbms_document_uuids(
          documents_service,
          profile.participant_id
        )

        directory = Rails.root / 'tmp' / name.underscore / claim_id
        FileUtils.mkdir_p(directory)
        File.write(directory / 'claim.json', JSON.pretty_generate(claim))

        filenames = []

        claim_documents.each do |document|
          uuid = vbms_document_uuids[document[:uuid]]
          file = download_document(documents_service, uuid, profile.birls_id)

          filenames << document[:type]
          filename = [
            document[:type],
            filenames.count(document[:type]),
            document[:extname]
          ].join

          File.binwrite(directory / filename, file)
        end
      end

      private

      def download_document(service, document_uuid, file_number)
        log_call
        service.participant_documents_download(document_uuid:, file_number:).body
      end

      def fetch_claim(service, id)
        log_call
        service.get_claim(id)
      end

      def get_claim_documents(claim)
        documents = claim.dig(
          *%w[data attributes supportingDocuments]
        ).to_a

        documents.lazy.map do |document|
          type = document['documentTypeLabel'].to_s.parameterize
          uuid = normalize_uuid(document['documentId'])
          extname = File.extname(document['originalFileName'])
          { type:, uuid:, extname: }
        end
      end

      ##
      # NOTE: The documents returned by LH Benefits Claims API when fetching a
      # claim do not include the ID that is needed by LH Benefits Documents
      # API for downloading documents. Until that changes, we need this ID
      # cross-reference.
      #
      def fetch_vbms_document_uuids(service, participant_id)
        {}.tap do |memo|
          page_number = 1
          page_size = 100

          loop do
            log_call
            response = service.participant_documents_search(
              participant_id:,
              page_number:,
              page_size:
            )

            documents = response.body.dig(*%w[data documents]).to_a
            documents.each do |document|
              key = normalize_uuid(document['currentVersionUuid'])
              value = normalize_uuid(document['documentUuid'])
              memo[key] = value
            end

            break if documents.size < page_size

            page_number += 1
          end
        end
      end

      def fetch_profile(service, identifier)
        log_call
        service.find_profile_by_identifier(
          identifier_type: MPI::Constants::ICN,
          identifier:
        ).profile
      end

      def normalize_uuid(uuid)
        uuid.delete('{}')
      end

      ##
      # This is mostly meant to show the user each slow network call, so they
      # know what they're waiting for. Therefore, it should be placed ahead of
      # any such call.
      #
      def log_call
        message = "#{self}.#{caller_locations(1, 1).first.base_label}"
        Rails.logger.info message
      end
    end
  end
end
