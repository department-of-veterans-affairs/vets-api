# frozen_string_literal: true

module VBMS
  class SubmitDependentsPdfJob
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Worker
    include SentryLogging

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, va_file_number_with_payload, submittable_686, submittable_674)
      Rails.logger.info('VBMS::SubmitDependentsPdfJob running!', { saved_claim_id: })
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.add_veteran_info(va_file_number_with_payload)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      claim.persistent_attachments.each do |attachment|
        file_extension = File.extname(URI.parse(attachment.file.url).path)
        if %w[.jpg .jpeg .png .pdf].include? file_extension.downcase
          file_path = Common::FileHelpers.generate_temp_file(attachment.file.read)

          File.rename(file_path, "#{file_path}#{file_extension}")
          file_path = "#{file_path}#{file_extension}"

          claim.upload_to_vbms(path: file_path, doc_type: get_doc_type(attachment.guid, claim.parsed_form))
          Common::FileHelpers.delete_file_if_exists(file_path)
        end
      end

      generate_pdf(claim, submittable_686, submittable_674)
      Rails.logger.info('VBMS::SubmitDependentsPdfJob succeeded!', { saved_claim_id: })
    rescue => e
      Rails.logger.error('VBMS::SubmitDependentsPdfJob failed!', { saved_claim_id:, error: e.message })
      send_error_to_sentry(e, saved_claim_id)
      false
    end

    private

    def send_error_to_sentry(error, saved_claim_id)
      log_exception_to_sentry(
        error,
        {
          claim_id: saved_claim_id
        },
        { team: 'vfs-ebenefits' }
      )
    end

    def generate_pdf(claim, submittable_686, submittable_674)
      claim.upload_pdf('686C-674') if submittable_686
      claim.upload_pdf('21-674', doc_type: '142') if submittable_674
    end

    def get_doc_type(guid, parsed_form)
      doc_type = check_doc_type(guid, parsed_form, 'spouse')
      return doc_type if doc_type.present?

      doc_type = check_doc_type(guid, parsed_form, 'child')
      return doc_type if doc_type.present?

      '10' # return '10' which is doc type 'UNKNOWN'
    end

    def check_doc_type(guid, parsed_form, dependent_type)
      supporting_documents = parsed_form['dependents_application']['spouse_supporting_documents']
      evidence_type = parsed_form['dependents_application']['spouse_evidence_document_type']

      if dependent_type == 'child'
        supporting_documents = parsed_form['dependents_application']['child_supporting_documents']
        evidence_type = parsed_form['dependents_application']['child_evidence_document_type']
      end

      if supporting_documents.present?
        guid_matches = supporting_documents.any? { |doc| doc['confirmation_code'] == guid }
        return evidence_type if guid_matches && evidence_type.present?
      end
    end
  end
end
