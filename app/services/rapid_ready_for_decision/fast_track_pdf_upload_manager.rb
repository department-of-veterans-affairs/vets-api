# frozen_string_literal: true

module RapidReadyForDecision
  class FastTrackPdfUploadManager
    attr_accessor :submission

    DOCUMENT_TITLE = 'VAMC_Hypertension_Rapid_Decision_Evidence'

    def initialize(submission)
      @submission = submission
    end

    def file_upload_name
      @file_upload_name ||= begin
        search_date = Time.zone.today.strftime('%Y%m%d')
        "#{DOCUMENT_TITLE}-#{search_date}.pdf"
      end
    end

    def add_upload(confirmation_code)
      data = JSON.parse(submission.form_json)
      uploads = data['form526_uploads'] || []
      new_upload = {
        name: file_upload_name,
        confirmationCode: confirmation_code,
        attachmentId: 'L048'
      }
      uploads.append(new_upload)
      data['form526_uploads'] = uploads
      submission.update!(form_json: JSON.dump(data))
      submission.invalidate_form_hash
      submission
    end

    def already_has_summary_file
      data = JSON.parse(submission.form_json)
      uploads = data['form526_uploads'] || []
      uploads.any? { |upload| upload['name'].start_with? DOCUMENT_TITLE }
    end

    def handle_attachment(pdf_body, add_to_submission: true)
      if already_has_summary_file
        submission
      else
        supporting_evidence_attachment = SupportingEvidenceAttachment.new
        file = FastTrackPDF.new(pdf_body, file_upload_name)
        supporting_evidence_attachment.set_file_data!(file)
        supporting_evidence_attachment.save!
        confirmation_code = supporting_evidence_attachment.guid
        submission.add_metadata(pdf_guid: confirmation_code)

        add_upload(confirmation_code) if add_to_submission && confirmation_code.present?
      end
    end

    # sets up attributes which the SupportingEvidenceAttachment class
    # and CarrierWave will expect in order to upload our PDF to S3
    #
    FastTrackPDF = Struct.new(:stream, :filename) do
      def original_filename
        filename
      end

      def fast_track
        true
      end

      def content_type
        'application/pdf'
      end

      def read
        stream
      end
    end
  end
end
