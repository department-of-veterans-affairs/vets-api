# frozen_string_literal: true

namespace :decision_reviews do
  desc 'Update return_url for in-progress Supplemental Claims forms requiring 4142 re-authorization'
  task update_in_progress_sc: :environment do
    puts 'Starting update of return_url for Supplemental Claims forms...'

    # Define the new return URL for 4142 legalese page
    new_return_url = '/supporting-evidence/private-medical-records-authorization'

    # Counter for tracking updates
    updated_count = 0
    total_processed = 0
    failed_ids = []

    # Find all in-progress saved forms for Supplemental Claims
    in_progress_forms = InProgressForm.where(form_id: '20-0995')

    puts "Found #{in_progress_forms.count} in-progress Supplemental Claims forms to process."

    in_progress_forms.find_in_batches(batch_size: 500) do |batch|
      puts "Processing batch of #{batch.size} forms..."

      batch.each do |in_progress_form|
        total_processed += 1

        begin
          form_data = in_progress_form.data_and_metadata[:formData] || {}

          # Check if conditions are met - both keys must be present and true
          has_privacy_agreement_accepted = form_data['privacy_agreement_accepted'] == true
          has_private_evidence = form_data['view:has_private_evidence'] == true

          if has_privacy_agreement_accepted && has_private_evidence
            metadata = in_progress_form.metadata || {}
            old_return_url = metadata['return_url']

            # Update the return_url
            metadata['return_url'] = new_return_url unless metadata['return_url'] == new_return_url
            in_progress_form.metadata = metadata

            if in_progress_form.save
              updated_count += 1
              puts "✓ Updated return_url for user #{in_progress_form.user_uuid} (ID: #{in_progress_form.id})"
              puts "  Old return_url: #{old_return_url || 'none'}"
              puts "  New return_url: #{new_return_url}"
            else
              failed_ids << in_progress_form.id
              puts "✗ Failed to save changes for user #{in_progress_form.user_uuid} (ID: #{in_progress_form.id})"
              puts "  Errors: #{in_progress_form.errors.full_messages.join(', ')}"
            end
          else
            puts "- Skipped user #{in_progress_form.user_uuid} (ID: #{in_progress_form.id}) - conditions not met"
            puts "
              privacy_agreement_accepted: #{form_data['privacy_agreement_accepted']},
              view:has_private_evidence: #{form_data['view:has_private_evidence']}
            "
          end
        rescue => e
          failed_ids << in_progress_form.id
          puts "
            ✗ Unexpected error processing user #{in_progress_form.user_uuid} (ID: #{in_progress_form.id}): #{e.message}
          "
        end
      end

      # Progress indicator after each batch
      puts "Progress: #{total_processed}/#{in_progress_forms.count} processed, #{updated_count} updated\n"
    end

    puts "\n#{'=' * 50}"
    puts 'Task completed!'
    puts "Total forms processed: #{total_processed}"
    puts "Forms updated: #{updated_count}"
    puts "Forms skipped: #{total_processed - updated_count - failed_ids.length}"
    puts "Forms failed to save: #{failed_ids.length}"

    if failed_ids.any?
      puts "\nFailed InProgressForm IDs:"
      puts failed_ids.join(', ')
      puts "\nTo investigate failures, you can query:"
      puts "InProgressForm.where(id: [#{failed_ids.join(', ')}])"
    end
    puts '=' * 50
  end

  desc 'Dry run: Preview which Supplemental Claims forms would be updated'
  task preview_update_in_progress_sc: :environment do
    puts 'DRY RUN: Previewing Supplemental Claims forms that would be updated...'

    new_return_url = '/supporting-evidence/private-medical-records-authorization'
    eligible_count = 0
    total_count = 0

    in_progress_forms = InProgressForm.where(form_id: '20-0995')
    puts "Found #{in_progress_forms.count} in-progress Supplemental Claims forms\n"

    in_progress_forms.find_in_batches(batch_size: 500) do |batch|
      puts "Processing batch of #{batch.size} forms..."

      batch.each do |in_progress_form|
        total_count += 1

        begin
          # Use data_and_metadata method to access form data
          form_data = in_progress_form.data_and_metadata[:formData] || {}

          # Check conditions - both keys must be present and true
          has_privacy_agreement_accepted = form_data['privacy_agreement_accepted'] == true
          has_private_evidence = form_data['view:has_private_evidence'] == true

          if has_privacy_agreement_accepted && has_private_evidence
            eligible_count += 1
            metadata = in_progress_form.metadata || {}
            current_return_url = metadata['return_url']

            puts "Would update user #{in_progress_form.user_uuid} (ID: #{in_progress_form.id})"
            puts "  Current return_url: #{current_return_url || 'none'}"
            puts "  New return_url: #{new_return_url}"
            puts "  Last updated: #{in_progress_form.updated_at}"
            puts ''
          end
        rescue => e
          puts "Error processing user #{in_progress_form.user_uuid}: #{e.message}"
        end
      end

      # Progress after each batch
      puts "Batch completed: #{total_count} processed so far, #{eligible_count} eligible\n"
    end

    puts '=' * 50
    puts 'DRY RUN SUMMARY:'
    puts "Total forms: #{total_count}"
    puts "Eligible for update: #{eligible_count}"
    puts "Would skip: #{total_count - eligible_count}"
    puts '=' * 50
    puts "\nTo execute the actual updates, run:"
    puts 'rails decision_reviews:update_return_url_for_4142'
  end
end
