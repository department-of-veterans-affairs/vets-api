# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_utilities/datestamp_pdf'

module Burials
  module ZeroSilentFailures
    class ManualRemediation
      def package_claim(saved_claim_id)
        @claim = SavedClaim::Burial.find(saved_claim_id)

        generate_metadata

        generate_form_pdf

        generate_attachment_pdfs

        zipfile = zip_files(files)
        Rails.logger.info("Packaged #{claim.form_id} #{claim.id} - #{zipfile}")

        if Settings.vsp_environment == 'production'
          link = aws_upload_zipfile(zipfile)
          Rails.logger.info("Download #{link}")
          Common::FileHelpers.delete_file_if_exists(zipfile)
        end
      end

      private

      attr_reader :claim

      def files
        @files ||= []
      end

      def generate_metadata
        form = claim.parsed_form
        address = form['claimantAddress'] || form['veteranAddress']

        lighthouse_benefit_intake_submission = FormSubmission.where(saved_claim_id: claim.id).order(id: :asc).last

        metadata = {
          claimId: claim.id,
          docType: claim.form_id,
          formStartDate: claim.form_start_date,
          claimSubmissionDate: claim.created_at,
          claimConfirmation: claim.guid,
          veteranFirstName: form['veteranFullName']['first'],
          veteranLastName: form['veteranFullName']['last'],
          fileNumber: form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          zipCode: address['postalCode'],
          businessLine: claim.business_line,
          lighthouseBenefitIntakeSubmissionUUID: lighthouse_benefit_intake_submission&.benefits_intake_uuid,
          lighthouseBenefitIntakeSubmissionDate: lighthouse_benefit_intake_submission&.created_at
        }

        metafile = Common::FileHelpers.generate_random_file(metadata.to_json)
        files << { name: "#{claim.form_id}_#{claim.id}-metadata.json", path: metafile }
      end

      def generate_form_pdf
        filepath = claim.to_pdf
        Rails.logger.info "Stamping #{claim.form_id} #{claim.id} - #{filepath}"
        stamped = stamp_pdf(filepath, claim.created_at)
        if ['21P-530V2'].include?(claim.form_id)
          stamped = stamped_pdf_with_form(claim.form_id, stamped,
                                          claim.created_at)
        end
        files << { name: File.basename(filepath), path: stamped }
      end

      def generate_attachment_pdfs
        claim.persistent_attachments.each do |pa|
          filename = "#{claim.form_id}_#{claim.id}-attachment_#{pa.id}.pdf"
          filepath = pa.to_pdf
          Rails.logger.info "Stamping #{claim.form_id} #{claim.id} Attachment #{pa.id} - #{filepath}"
          stamped = stamp_pdf(filepath, claim.created_at)
          if ['21P-530V2'].include?(claim.form_id)
            stamped = stamped_pdf_with_form(claim.form_id, stamped,
                                            claim.created_at)
          end
          files << { name: filename, path: stamped }
        end
      end

      def stamp_pdf(pdf_path, timestamp = nil)
        begin
          datestamp = PDFUtilities::DatestampPdf.new(pdf_path).run(text: 'VA.GOV', x: 5, y: 5, timestamp:)
          watermark = PDFUtilities::DatestampPdf.new(datestamp).run(
            text: 'FDC Reviewed - VA.gov Submission',
            x: 400,
            y: 770,
            text_only: true,
            timestamp:
          )
        rescue
          Rails.logger.error "Error stamping pdf: #{pdf_path}"
        end

        watermark || pdf_path
      end

      def stamped_pdf_with_form(form_id, path, timestamp)
        PDFUtilities::DatestampPdf.new(path).run(
          text: 'Application Submitted on va.gov',
          x: 425,
          y: 675,
          text_only: true, # passing as text only because we override how the date is stamped in this instance
          timestamp:,
          page_number: 5,
          size: 9,
          template: "lib/pdf_fill/forms/pdfs/#{form_id}.pdf",
          multistamp: true
        )
      end

      def zip_files(files)
        zip_file_path = "#{Common::FileHelpers.random_file_path}.zip"
        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
          files.each do |file|
            Rails.logger.info(file)
            begin
              zipfile.add(file[:name], file[:path])
            rescue
              Rails.logger.error "Error adding to zip: #{file}"
            end
          end
        end
        zip_file_path
      end

      def aws_upload_zipfile(zipfile)
        s3_resource = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                            access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                            secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        obj = s3_resource.bucket(Settings.vba_documents.s3.bucket).object(File.basename(zipfile))
        obj.upload_file(zipfile, content_type: Mime[:zip].to_s)
        obj.presigned_url(:get, expires_in: 1.day.to_i)
      end
    end
  end
end
