# frozen_string_literal: true

module FastTrack
  class HypertensionUploadManager
    attr_accessor :submission

    def initialize(submission)
      @submission = submission
    end

    def add_upload(confirmation_code)
      data = JSON.parse(submission.form_json)
      uploads = data['form526_uploads'] || []
      new_upload = {
        name: 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf',
        confirmationCode: confirmation_code,
        attachmentId: '1489'
      }
      uploads.append(new_upload)
      data['form526_uploads'] = uploads
      submission.update(form_json: JSON.dump(data))
      submission
    end

    def already_has_summary_file
      data = JSON.parse(submission.form_json)
      uploads = data['form526_uploads'] || []
      uploads.any? { |upload| upload['name'].start_with? 'VAMC_Hypertension_Rapid_Decision_Evidence' }
    end

    def handle_attachment(pdf_body)
      if already_has_summary_file
        submission
      else
        supporting_evidence_attachment = SupportingEvidenceAttachment.new
        file = FastTrackPDF.new(pdf_body, 'VAMC_Hypertension_Rapid_Decision_Evidence.pdf')
        supporting_evidence_attachment.set_file_data!(file)
        supporting_evidence_attachment.save!
        confirmation_code = supporting_evidence_attachment.guid

        add_upload(confirmation_code) unless confirmation_code.nil?
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
