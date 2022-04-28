# frozen_string_literal: true

module RapidReadyForDecision
  class FastTrackPdfUploadManager
    attr_accessor :submission

    DOCUMENT_NAME_PREFIX = 'VAMC'
    DOCUMENT_NAME_SUFFIX = 'Rapid_Decision_Evidence'

    def initialize(claim_context)
      @claim_context = claim_context
      @submission = claim_context.submission
    end

    def file_upload_name
      @file_upload_name ||= begin
        search_date = Time.zone.today.strftime('%Y%m%d')
        contention = @claim_context.disability_struct[:label].capitalize
        document_title = "#{DOCUMENT_NAME_PREFIX}_#{contention}_#{DOCUMENT_NAME_SUFFIX}"
        "#{document_title}-#{search_date}.pdf"
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

    def handle_attachment(pdf_body, add_to_submission: true)
      if submission.rrd_pdf_added_for_uploading?
        submission
      else
        supporting_evidence_attachment = SupportingEvidenceAttachment.new
        file = FastTrackPDF.new(pdf_body, file_upload_name)
        supporting_evidence_attachment.set_file_data!(file)
        supporting_evidence_attachment.save!
        confirmation_code = supporting_evidence_attachment.guid
        @claim_context.add_metadata(pdf_guid: confirmation_code)

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
