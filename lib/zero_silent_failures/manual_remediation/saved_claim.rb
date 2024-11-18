# frozen_string_literal: true

require 'common/file_helpers'
require 'pdf_utilities/datestamp_pdf'

module ZeroSilentFailures
  module ManualRemediation
    # super class for manual remediation of a SavedClaim type
    class SavedClaim
      attr_reader :claim, :zipfile, :aws_download_zip_link

      # constructor
      #
      # @param saved_claim_id [Integer] the id of the claim needing manual remediation
      def initialize(saved_claim_id)
        @claim = claim_class.find(saved_claim_id)
        @zipfile = "#{Common::FileHelpers.random_file_path}.zip"
      end

      # process the _claim_ for remediation:
      # - generate and stamp claim and attachment pdf
      # - create a zipfile of generated pdf and metadata.json
      # - upload zipfile to AWS S3 bucket (only if running on prod)
      # - update database records for claim FormSubmissionAttempts
      # - all generated files are deleted
      def run
        Rails.logger.info "Manual Remediation for #{claim.form_id} #{claim.id} started"

        # reset in case there are multiple runs with the same instance
        @files = []

        package_claim
        upload_documents
        update_database

        Rails.logger.info "Manual Remediation for #{claim.form_id} #{claim.id} Complete!"
      ensure
        Common::FileHelpers.delete_file_if_exists(zipfile) if on_prod?
        files.each { |file| Common::FileHelpers.delete_file_if_exists(file[:path]) }
      end

      # generate metadata, claim.pdf, attachment.pdf, and zip
      def package_claim
        files << generate_metadata_json
        files << generate_form_pdf

        claim.persistent_attachments.each do |pa|
          files << generate_attachment_pdf(pa)
        end

        zip_files
      end

      # upload documents to s3 bucket (only if running on prod)
      def upload_documents
        Rails.logger.info "Uploading documents - #{claim.form_id} #{claim.id}"

        aws_upload_zipfile if on_prod?
        # @todo ? upload to sharepoint directly ?

        aws_download_zip_link || zipfile
      end

      # update FormSubmissionAttempt records for _claim_
      def update_database
        Rails.logger.info "Updating database - #{claim.form_id} #{claim.id}"

        fs_ids = claim.form_submissions.map(&:id)
        FormSubmissionAttempt.where(form_submission_id: fs_ids, aasm_state: 'failure')&.map(&:manual!)
      end

      private

      # is the current environment production
      def on_prod?
        Settings.vsp_environment == 'production'
      end

      # claim class to be used
      # - inheritor should override to specific type
      def claim_class
        ::SavedClaim
      end

      # array of files to be packaged
      def files
        @files ||= []
      end

      # assemble metadata for _claim_
      # - inheritor should append to _super_ if needed
      def generate_metadata
        form = claim.parsed_form
        address = form['claimantAddress'] || form['veteranAddress']

        {
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
      end

      # create the _claim_ metadata.json file
      # @return [Hash] the name and path to the file
      def generate_metadata_json
        metadata = generate_metadata

        metafile = Common::FileHelpers.generate_random_file(metadata.to_json)
        { name: "#{claim.form_id}_#{claim.id}-metadata.json", path: metafile }
      end

      # create and stamp the _claim_ form pdf
      # @return [Hash] the name and path to the file
      def generate_form_pdf
        filepath = claim.to_pdf
        Rails.logger.info "Stamping #{claim.form_id} #{claim.id} - #{filepath}"
        stamped = stamp_pdf(filepath, claim.created_at)

        { name: File.basename(filepath), path: stamped }
      end

      # create and stamp a _claim_ attachment pdf
      # @return [Hash] the name and path to the file
      def generate_attachment_pdf(pa)
        filename = "#{claim.form_id}_#{claim.id}-attachment_#{pa.id}.pdf"
        filepath = pa.to_pdf
        Rails.logger.info "Stamping #{claim.form_id} #{claim.id} Attachment #{pa.id} - #{filepath}"
        stamped = stamp_pdf(filepath, claim.created_at)

        { name: filename, path: stamped }
      end

      # list of stamps to be applied to a generated pdf for _claim_
      # - inheritor should append to _super_ if needed
      #
      # @see PDFUtilites::DatestampPdf#run
      #
      # @param timestamp [String|Datetime] the timestamp to be used; should be the claim.created_at
      #
      # @return [Array<Hash>] the list of stamps to be applied
      def stamps(timestamp)
        [
          { text: 'VA.GOV', x: 5, y: 5, timestamp: }
        ]
      end

      # stamp a generated pdf
      # if there is an error stamping the pdf, the original path is returned
      # - user uploaded attachments can be malformed
      #
      # @see PDFUtilites::DatestampPdf#run
      #
      # @param pdf_path [String] the path to a generated pdf; ie. claim.to_pdf
      # @param timestamp [String|Datetime] the timestamp to be used; should be the claim.created_at
      #
      # @return [String] the path to the stamped pdf
      def stamp_pdf(pdf_path, timestamp)
        stamped = pdf_path
        stamps(timestamp).each do |stamp|
          previous = stamped
          stamped = PDFUtilities::DatestampPdf.new(previous).run(**stamp)
          Common::FileHelpers.delete_file_if_exists(previous)
        end

        stamped
      rescue
        Common::FileHelpers.delete_file_if_exists(stamped) if stamped != pdf_path
        Rails.logger.error "Error stamping pdf: #{pdf_path}"
        pdf_path
      end

      # package all _files_ for _claim_
      # @raise Error if unable to add a file to the zip
      def zip_files
        Zip::File.open(zipfile, Zip::File::CREATE) do |zip|
          files.each do |file|
            Rails.logger.info("Adding to zip: #{file}")
            zip.add(file[:name], file[:path])
          rescue => e
            Rails.logger.error "Error adding to zip: #{file}"
            raise e
          end
        end

        Rails.logger.info("Packaged #{claim.form_id} #{claim.id} - #{zipfile}")
      end

      # upload _zipfile_ to AWS
      # @see Aws::S3::Resource
      # @raise Error if unable to upload
      def aws_upload_zipfile
        s3_resource = Aws::S3::Resource.new(region: Settings.vba_documents.s3.region,
                                            access_key_id: Settings.vba_documents.s3.aws_access_key_id,
                                            secret_access_key: Settings.vba_documents.s3.aws_secret_access_key)
        obj = s3_resource.bucket(Settings.vba_documents.s3.bucket).object(File.basename(zipfile))
        obj.upload_file(zipfile, content_type: Mime[:zip].to_s)
        @aws_download_zip_link = obj.presigned_url(:get, expires_in: 1.day.to_i)

        Rails.logger.info("AWS Download Zip Link #{aws_download_zip_link}")
      rescue => e
        Rails.logger.error 'Error uploading to AWS'
        raise e
      end
    end
  end
end
