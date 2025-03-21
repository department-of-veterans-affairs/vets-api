# frozen_string_literal: true

module IvcChampva
  module ProdSupportUtilities
    class MissingStatusCleanup
      # Displays a list of all form submission batches that include a missing PEGA status
      #
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID
      def get_missing_statuses
        all_nil_statuses = IvcChampvaForm.where(pega_status: nil)
        batches = batch_records(all_nil_statuses)
        # Print out details of each batch that contains a missing PEGA status:
        batches.each_value do |batch|
          display_batch(batch)
        end

        batches
      end

      # Displays a list of all form submission batches that match the provided email address.
      #
      # @param [String] email_addr email address to search for IvcChampvaForm records by
      #
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID, all with :email equal to to email_addr
      def get_batches_for_email(email_addr)
        results = IvcChampvaForm.where(email: email_addr)
        batches = batch_records(results)
        batches.each_value do |batch|
          display_batch(batch)
        end

        batches
      end

      # Collates the provided list of IvcChampvaForms into a hash of forms batched up by
      # their form_uuid property.
      #
      # @param [Array<IvcChampvaForm>] records Active record query result containing IvcChampvaForm items
      #
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID
      def batch_records(records)
        batches = {}

        # Group all records into batches by form UUID
        records.map do |el|
          batch = IvcChampvaForm.where(form_uuid: el.form_uuid)
          batches[el.form_uuid] = batch
        end

        batches
      end

      # Displays the provided IvcChampvaForm items in batches, grouped by form_uuid
      #
      # @param [Array<IvcChampvaForm>] batch list of IvcChampvaForm items with the same form_uuid
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

      # Set the `pega_status` property to "Manually Processed" for all IvcChampvaForm
      # items contained in the provided batch.
      #
      # @param [Array<IvcChampvaForm>] batch list of IvcChampvaForm items with the same form_uuid
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID
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
