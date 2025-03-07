# frozen_string_literal: true

module IvcChampva
  module ProdSupportUtilities
    class MissingStatusCleanup
      def get_missing_statuses
        all_nil_statuses = IvcChampvaForm.where(pega_status: nil)
        batches = batch_records(all_nil_statuses)
        # Print out details of each batch that contains a missing PEGA status:
        batches.each_value do |batch|
          display_batch(batch)
        end

        batches
      end

      # TODO: Condense functionality - this method is way too similar to the above
      def get_batches_for_email(email_addr)
        results = IvcChampvaForm.where(email: email_addr)
        batches = batch_records(results)
        batches.each_value do |batch|
          display_batch(batch)
        end

        batches
      end

      # records: a list of IvcChampvaForm active records
      def batch_records(records)
        batches = {}

        # Group all records into batches by form UUID
        records.map do |el|
          batch = IvcChampvaForm.where(form_uuid: el.form_uuid)
          batches[el.form_uuid] = batch
        end

        batches
      end

      # batch: a list of IvcChampvaForm active records with the same form UUIDs
      def display_batch(batch)
        return unless batch.count.positive?

        nil_in_batch = batch.where(pega_status: nil)

        form = batch[0] # Grab a representative form
        fraction = "#{nil_in_batch.length}/#{batch.length}"
        puts '---'
        puts "#{form.first_name} #{form.last_name} missing PEGA status on #{fraction} attachments - #{form.email}\n"
        puts "Form UUID:   #{form.form_uuid}"
        puts "Form:   #{form.form_number}"
        puts "Uploaded at: #{form.created_at}"
        puts "S3 Status:   #{nil_in_batch.distinct.pluck(:s3_status)}\n"

        nil
      end

      # batch: a list of IvcChampvaForm active records with the same form UUIDs
      def manually_process_batch(batch)
        batch.each do |form|
          next unless form.pega_status.nil?

          puts "Setting #{form.file_name} to 'Manually Processed'"
          form.update(pega_status: 'Manually Processed')
          form.save
        end

        batch
      end
    end
  end
end
