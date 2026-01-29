# frozen_string_literal: true

module DisabilityCompensation
  ##
  # TODO: Describe how to set settings for Benefits Claims API and
  # Benefits Documents API. This includes `host` and `access_token` for both.
  #
  module DownloadDocuments
    class << self
      def perform(id_type:, id_value:)
        directory = Rails.root / 'tmp' / name.underscore / "#{id_type}-#{id_value}"
        FileUtils.mkdir_p(directory)

        submission = find_submission(
          id_type,
          id_value
        )

        claim = fetch_claim(
          submission.submitted_claim_id,
          submission.account.icn
        )

        documents = claim['supportingDocuments'].to_a
        file_number, participant_id = submission.auth_headers.values_at(
          *%w[va_eauth_birlsfilenumber va_eauth_pid]
        )

        download_documents(documents, participant_id:, file_number:) do |name, file|
          File.binwrite(directory / name, file)
        end
      end

      private

      def download_documents(documents, **)
        service = BenefitsDocuments::Service.new(:__UNUSED__)
        names = []

        documents.each do |document|
          name_prefix = document['documentTypeLabel'].to_s.parameterize
          names << name_prefix

          name_suffix = names.count(name_prefix)
          name = "#{name_prefix}-#{name_suffix}"

          document_uuid = document['documentId'].delete('{}')
          response = service.participant_documents_download(document_uuid:, **)
          file = response.body

          yield(name, file)
        end
      end

      def fetch_claim(id, icn)
        service = BenefitsClaims::Service.new(icn)
        response = service.get_claim(id).to_h
        response.dig(*%w[data attributes]).to_h
      end

      def find_submission(id_type, id_value)
        find_by =
          case id_type.to_sym
          when :submission_id
            { id: id_value }
          when :claim_id
            { submitted_claim_id: id_value }
          when :job_id
            { form526_job_statuses: { job_class: 'SubmitForm526AllClaim', job_id: id_value } }
          else
            raise ArgumentError, <<~MSG.squish
              `id_type` must be one of `(
                claim_id, job_id, submission_id
              )`
            MSG
          end

        Form526Submission
          .left_joins(:form526_job_statuses)
          .find_by!(find_by)
      end
    end
  end
end
