# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_utilities/datestamp_pdf'

module ZeroSilentFailures
  module ManualRemediation
    class SavedClaim

      attr_reader :claim, :metadata, :zipfile, :aws_download_zip_link

      def intialize(saved_claim_id)
        @claim = SavedClaim.find(saved_claim_id)
        @zipfile = "#{Common::FileHelpers.random_file_path}.zip"
      end

      def run
        Rails.logger.info "Manual Remediation for #{claim.form_id} #{claim.id}"
        package_claim
        upload_documents
        update_database
        Rails.logger.info " ... Complete!"
      ensure
        Common::FileHelpers.delete_file_if_exists(zipfile)
        files.each { |file| Common::FileHelpers.delete_file_if_exists(file[:path]) }
      end

      def package_claim
        files << generate_metadata
        files << generate_form_pdf
        files << generate_attachment_pdfs
        zip_files
      end

      def upload_documents
        Rails.logger.info "Uploading documents for #{claim.form_id} #{claim.id}"

        aws_upload_zipfile if Settings.vsp_environment == 'production'

        aws_download_zip_link || zipfile
      end

      def update_database
        Rails.logger.info "Updating Database - #{claim.form_id} #{claim.id}"
      end

      private

      def files
        @files ||= []
      end

      def generate_metadata
        form = claim.parsed_form
        address = form['claimantAddress'] || form['veteranAddress']

        @metadata = {
          claimId: claim.id,
          docType: claim.form_id,
          formStartDate: claim.form_start_date,
          claimSubmissionDate: claim.created_at,
          claimConfirmation: claim.guid,
          veteranFirstName: form['veteranFullName']['first'],
          veteranLastName: form['veteranFullName']['last'],
          fileNumber: form['vaFileNumber'] || form['veteranSocialSecurityNumber'],
          zipCode: address['postalCode'],
          businessLine: claim.business_line
        }

        metafile = Common::FileHelpers.generate_random_file(metadata.to_json)
        { name: "#{claim.form_id}_#{claim.id}-metadata.json", path: metafile }
      end

      def generate_form_pdf
        filepath = claim.to_pdf
        Rails.logger.info "Stamping #{claim.form_id} #{claim.id} - #{filepath}"
        stamped = stamp_pdf(filepath, claim.created_at)

        { name: File.basename(filepath), path: stamped }
      end

      def generate_attachment_pdfs
        claim.persistent_attachments.each do |pa|
          filename = "#{claim.form_id}_#{claim.id}-attachment_#{pa.id}.pdf"
          filepath = pa.to_pdf
          Rails.logger.info "Stamping #{claim.form_id} #{claim.id} Attachment #{pa.id} - #{filepath}"
          stamped = stamp_pdf(filepath, claim.created_at)

          { name: filename, path: stamped }
        end
      end

      def stamps(timestamp)
        [
          { text: 'VA.GOV', x: 5, y: 5, timestamp: }
        ]
      end

      def stamp_pdf(pdf_path, timestamp)
        stamped = pdf_path
        stamps(timestamp).each do |stamp|
          stamped = PDFUtilities::DatestampPdf.new(stamped).run(**stamp)
        end

        stamped
      rescue
        Rails.logger.error "Error stamping pdf: #{pdf_path}"
        pdf_path
      end

      def zip_files
        Zip::File.open(zipfile, Zip::File::CREATE) do |zip|
          files.each do |file|
            Rails.logger.info("Adding to zip: #{file}")
            zip.add(file[:name], file[:path])
          end
        end

        Rails.logger.info("Packaged #{claim.form_id} #{claim.id} - #{zipfile}")
      rescue => e
        Rails.logger.error "Error adding to zip: #{file}"
        raise e
      end

      def aws_upload_zipfile
        s3_resource = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                            access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                            secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        obj = s3_resource.bucket(Settings.vba_documents.s3.bucket).object(File.basename(zipfile))
        obj.upload_file(zipfile, content_type: Mime[:zip].to_s)
        @aws_download_zip_link = obj.presigned_url(:get, expires_in: 1.day.to_i)

        Rails.logger.info("AWS Download Zip Link #{aws_download_zip_link}")
      rescue => e
        Rails.logger.error "Error uploading to AWS"
        raise e
      end
    end
  end
end
