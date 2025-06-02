# frozen_string_literal: true

module VBMS
  class SubmitDependentsPdfV2Job
    class Invalid686cClaim < StandardError; end
    include Sidekiq::Job
    include SentryLogging

    # retry for  2d 1h 47m 12s
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
    sidekiq_options retry: 16
    attr_reader :claim

    sidekiq_retries_exhausted do |msg, error|
      Rails.logger.error('VBMS::SubmitDependentsPdfJob failed, retries exhausted!',
                         { saved_claim_id: msg['args'][0], error: })
    end

    # Generates PDF for 686c form and uploads to VBMS
    def perform(saved_claim_id, encrypted_vet_info, submittable_686_form, submittable_674_form)
      va_file_number_with_payload = JSON.parse(KmsEncrypted::Box.new.decrypt(encrypted_vet_info))
      Rails.logger.info('VBMS::SubmitDependentsPdfJob running!', { saved_claim_id: })
      @claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      claim.add_veteran_info(va_file_number_with_payload)

      raise Invalid686cClaim unless claim.valid?(:run_686_form_jobs)

      upload_attachments

      generate_pdf(submittable_686_form, submittable_674_form)
      Rails.logger.info('VBMS::SubmitDependentsPdfJob succeeded!', { saved_claim_id: })
    rescue => e
      Rails.logger.warn('VBMS::SubmitDependentsPdfJob failed, retrying...', { saved_claim_id:, error: e.message })
      @saved_claim_id = saved_claim_id
      raise
    end

    private

    def upload_attachments
      claim.persistent_attachments.each do |attachment|
        next if attachment.completed_at.present?

        file_extension = File.extname(URI.parse(attachment.file.url).path)
        if %w[.jpg .jpeg .png .pdf].include? file_extension.downcase
          file_path = Common::FileHelpers.generate_clamav_temp_file(attachment.file.read)

          File.rename(file_path, "#{file_path}#{file_extension}")
          file_path = "#{file_path}#{file_extension}"

          claim.upload_to_vbms(path: file_path, doc_type: get_doc_type(attachment.guid, claim.parsed_form))
          Common::FileHelpers.delete_file_if_exists(file_path)
        end
        attachment.update(completed_at: Time.zone.now)
      end
    end

    def generate_pdf(submittable_686_form, submittable_674_form)
      pdf686 = '686C-674-V2'
      pdf674 = '21-674-V2'
      claim.upload_pdf(pdf686) if submittable_686_form
      claim.upload_pdf(pdf674, doc_type: '142') if submittable_674_form
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
        evidence_type if guid_matches && evidence_type.present?
      end
    end
  end
end
