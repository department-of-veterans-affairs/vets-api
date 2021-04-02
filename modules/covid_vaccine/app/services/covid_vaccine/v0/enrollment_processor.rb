# frozen_string_literal: true

require 'covid_vaccine/v0/expanded_registration_csv_generator'

module CovidVaccine
  module V0
    class EnrollmentProcessor
      include SentryLogging

      def initialize(prefix: 'DHS_load')
        @batch_id = Time.now.utc.strftime('%Y%m%d%H%M%S')
        @prefix = prefix
      end

      attr_reader :batch_id

      def process_and_upload!
        records = batch_records!
        csv_generator = ExpandedRegistrationCsvGenerator.new(records)
        filename = generated_file_name(records.length)
        uploader = CovidVaccine::V0::EnrollmentUploadService.new(csv_generator.io, filename)
        uploader.upload
        update_state_to_pending
      rescue => e
        log_exception_to_sentry(
          e,
          { code: e.try(:code) },
          { external_service: 'EnrollmentService' }
        )
        raise
      end

      # rubocop:disable Rails/SkipsModelValidations
      def update_state_to_pending
        CovidVaccine::V0::ExpandedRegistrationSubmission
          .where(batch_id: @batch_id).update_all(state: 'enrollment_pending')
      end
      # rubocop:enable Rails/SkipsModelValidations

      # Writes CSV to file for an existing batch. Does not permute state of any records.
      # This is a convenience/failsafe mechanism for manual intervention
      def self.write_to_file(batch_id, stream)
        records = CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: batch_id)
        csv_generator = ExpandedRegistrationCsvGenerator.new(records)
        stream.write csv_generator.io.read
        records.length
      end

      # def self.set_pending_state(batch_id)
      #   CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: batch_id).find_each do |submission|
      #     submission.submitted_for_enrollment
      #     submission.save!
      #   end
      # end

      # TODO: Should this be private? Or public to be used by scanner job
      # rubocop:disable Rails/SkipsModelValidations
      def batch_records!
        records = CovidVaccine::V0::ExpandedRegistrationSubmission.where(state: 'received', batch_id: nil)
        records.update_all(batch_id: @batch_id)
        CovidVaccine::V0::ExpandedRegistrationSubmission.where(batch_id: @batch_id)
      end
      # rubocop:enable Rails/SkipsModelValidations

      def generated_file_name(record_count)
        "#{@prefix}_#{@batch_id}_SLA_#{record_count}_records.txt"
      end
    end
  end
end
