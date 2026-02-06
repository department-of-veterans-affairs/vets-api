# frozen_string_literal: true

module IvcChampva
  module ProdSupportUtilities
    class MissingStatusCleanup
      # Displays a list of all form submission batches that include a missing PEGA status
      #
      # @param [boolean] silent whether or not to `puts` the batch information
      # @param [boolean] ignore_last_minute whether or not to ignore submissions made < 1 minute ago
      # @param [boolean] ignore_recent whether or not to ignore submissions made < 2 hours ago
      #
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID
      def get_missing_statuses(silent: false, ignore_last_minute: false, ignore_recent: false)
        all_nil_statuses = IvcChampvaForm.where(pega_status: nil)
        if ignore_last_minute
          all_nil_statuses = all_nil_statuses.where('created_at < ?', 1.minute.ago)
        elsif ignore_recent
          all_nil_statuses = all_nil_statuses.where('created_at < ?', 2.hours.ago)
        end
        batches = batch_records(all_nil_statuses)

        return batches if silent

        # Print out details of each batch that contains a missing PEGA status:
        batches.each_value do |batch|
          display_batch(batch)
        end

        batches
      end

      # Displays a list of all form submission batches that match the provided email address.
      #
      # @param [String] email_addr email address to search for IvcChampvaForm records by
      # @param [boolean] silent whether or not to `puts` the batch information
      #
      # @returns [Hash] a hash where keys are form UUIDs and values are arrays of
      #   IvcChampvaForm records matching that UUID, all with :email equal to to email_addr
      def get_batches_for_email(email_addr:, silent: false)
        results = IvcChampvaForm.where(email: email_addr)
        batches = batch_records(results)

        return batches if silent

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
        # rubocop:disable Rails/Output
        puts '---'
        puts "#{form.first_name} #{form.last_name} missing PEGA status on #{fraction} attachments - #{form.email}\n"
        puts "Form UUID:   #{form.form_uuid}"
        puts "Form:   #{form.form_number}"
        puts "Uploaded at: #{form.created_at}"
        puts "S3 Status:   #{batch.distinct.pluck(:s3_status)}\n"
        # rubocop:enable Rails/Output

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

          # In this context, `form.file_name` has this structure: "#{uuid}_#{form_id}_supporting_doc-#{index}.pdf"
          Rails.logger.info("IVC ChampVA Forms - Setting #{form.file_name} to 'Manually Processed'")
          form.update(pega_status: 'Manually Processed')
          form.save
        end

        batch
      end
    end
  end
end
