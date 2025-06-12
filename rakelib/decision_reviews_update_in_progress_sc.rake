# frozen_string_literal: true

namespace :decision_reviews do
  desc 'Dry run to identify supplemental claims forms that need return URL updates'
  task dry_run_supplemental_claims_update: :environment do
    puts '=' * 80
    puts 'DRY RUN: Identifying supplemental claims forms needing return URL updates'
    puts "Started at: #{Time.current}"
    puts '=' * 80

    new_return_url = '/supporting-evidence/private-medical-records-authorization'

    # Counters for reporting
    total_forms = 0
    eligible_forms = 0
    already_correct = 0
    needs_update_data = [] # Store {id, original_return_url} for rollback capability

    # Track performance
    start_time = Time.current

    # Process in batches to manage memory
    InProgressForm.where(form_id: '20-0995').find_in_batches(batch_size: 1000) do |batch|
      batch_start_time = Time.current
      batch_eligible = 0
      batch_needs_update = 0
      batch_update_data = []

      batch.each do |form|
        total_forms += 1

        form_data = form.data_and_metadata[:formData] || {}
        has_privacy = form_data['privacy_agreement_accepted'] == true
        has_evidence = form_data['view:has_private_evidence'] == true

        if has_privacy && has_evidence
          eligible_forms += 1
          batch_eligible += 1

          metadata = form.metadata || {}
          current_return_url = metadata['return_url']

          if current_return_url == new_return_url
            already_correct += 1
          else
            # Store both ID and original value for rollback capability
            batch_update_data << {
              id: form.id,
              original_return_url: current_return_url
            }
            batch_needs_update += 1
          end
        end
      end

      # Add batch data to main collection
      needs_update_data.concat(batch_update_data)

      # Batch progress report
      batch_time = Time.current - batch_start_time
      puts "Batch completed: #{batch_eligible} eligible, #{batch_needs_update} need updates (#{batch_time.round(2)}s)"
    end

    total_time = Time.current - start_time

    puts '=' * 80
    puts 'DRY RUN SUMMARY'
    puts '=' * 80
    puts "Total forms analyzed: #{total_forms}"
    puts "Eligible forms (privacy=true AND evidence=true): #{eligible_forms}"
    puts "Already have correct return_url: #{already_correct}"
    puts "Need return_url update: #{needs_update_data.size}"
    puts "Processing time: #{total_time.round(2)} seconds (#{(total_forms / total_time).round(1)} forms/sec)"
    puts

    if needs_update_data.any?
      # Cache the data for both update and potential rollback
      cache_file = Rails.root.join('tmp', 'supplemental_claims_update_data.json')
      cache_data = {
        generated_at: Time.current.iso8601,
        new_return_url:,
        total_forms_scanned: total_forms,
        updates_needed: needs_update_data
      }
      File.write(cache_file, JSON.pretty_generate(cache_data))

      puts "Cached #{needs_update_data.size} form update data in:"
      puts "  #{cache_file}"
      puts '  (includes original return_url values for rollback capability)'
      puts
      puts 'Next steps:'
      puts '1. Review the summary above'
      puts '2. If satisfied, run: rake decision_reviews:update_in_progress_sc_from_cache'
      puts "3. The actual update will only process #{needs_update_data.size} forms instead of #{total_forms}"
      puts "   (#{((needs_update_data.size.to_f / total_forms) * 100).round(1)}% efficiency gain!)"
      puts '4. If rollback needed: rake decision_reviews:rollback_in_progress_sc_update'
    else
      puts 'All eligible forms already have the correct return_url! No updates needed.'
    end

    puts '=' * 80
  end

  desc 'Update supplemental claims return URLs using cached data from dry run'
  task update_in_progress_sc_from_cache: :environment do
    cache_file = Rails.root.join('tmp', 'supplemental_claims_update_data.json')

    unless File.exist?(cache_file)
      puts "ERROR: No cached data found at #{cache_file}"
      puts 'Please run the dry run first: rake decision_reviews:dry_run_supplemental_claims_update'
      exit 1
    end

    # Read cached data
    cache_data = JSON.parse(File.read(cache_file))
    new_return_url = cache_data['new_return_url']
    updates_needed = cache_data['updates_needed']

    puts '=' * 80
    puts 'UPDATING SUPPLEMENTAL CLAIMS RETURN URLs'
    puts "Started at: #{Time.current}"
    puts "Cache generated: #{cache_data['generated_at']}"
    puts "Processing #{updates_needed.size} pre-identified forms"
    puts "New return_url: #{new_return_url}"
    puts '=' * 80

    updated_count = 0
    error_count = 0
    start_time = Time.current

    # Process the specific forms that need updates
    updates_needed.each_slice(1000) do |batch_data|
      batch_start_time = Time.current
      batch_updated = 0
      batch_errors = 0

      batch_ids = batch_data.map { |item| item['id'] }
      InProgressForm.where(id: batch_ids).find_each do |form|
        # Double-check eligibility (defensive programming)
        form_data = form.data_and_metadata[:formData] || {}
        has_privacy = form_data['privacy_agreement_accepted'] == true
        has_evidence = form_data['view:has_private_evidence'] == true

        if has_privacy && has_evidence
          metadata = form.metadata || {}
          metadata['return_url'] = new_return_url
          form.metadata = metadata

          if form.save
            updated_count += 1
            batch_updated += 1
          else
            error_count += 1
            batch_errors += 1
            puts "  Failed to save form ID #{form.id}: #{form.errors.full_messages.join(', ')}"
          end
        else
          puts "  Form ID #{form.id} no longer eligible (data may have changed since dry run)"
          error_count += 1
          batch_errors += 1
        end
      rescue => e
        error_count += 1
        batch_errors += 1
        puts "  Error updating form ID #{form.id}: #{e.message}"
      end

      batch_time = Time.current - batch_start_time
      puts "Batch completed: #{batch_updated} updated, #{batch_errors} errors (#{batch_time.round(2)}s)"
    end

    total_time = Time.current - start_time

    puts
    puts '=' * 80
    puts 'UPDATE SUMMARY'
    puts '=' * 80
    puts "Forms processed: #{updates_needed.size}"
    puts "Successfully updated: #{updated_count}"
    puts "Errors: #{error_count}"
    puts "Processing time: #{total_time.round(2)} seconds (#{(updates_needed.size / total_time).round(1)} forms/sec)"
    puts

    if updated_count.positive?
      puts "SUCCESS: Updated return_url to '#{new_return_url}' for #{updated_count} forms"
      puts 'Rollback data preserved in cache file for safety'
    end

    if error_count.positive?
      puts "#{error_count} forms had errors - please review the output above"
      puts 'Cache file preserved for debugging and potential rollback'
    else
      puts 'All updates successful!'
      puts "Cache file preserved for potential rollback: #{cache_file}"
    end

    puts "Completed at: #{Time.current}"
    puts '=' * 80
  end

  desc 'Rollback supplemental claims return URL changes using cached original values'
  task rollback_in_progress_sc_update: :environment do
    cache_file = Rails.root.join('tmp', 'supplemental_claims_update_data.json')

    unless File.exist?(cache_file)
      puts "ERROR: No rollback data found at #{cache_file}"
      puts 'Rollback is only possible if you have the cache file from the dry run.'
      exit 1
    end

    cache_data = JSON.parse(File.read(cache_file))
    updates_needed = cache_data['updates_needed']
    new_return_url = cache_data['new_return_url']

    puts '=' * 80
    puts 'ROLLING BACK SUPPLEMENTAL CLAIMS RETURN URL CHANGES'
    puts "Started at: #{Time.current}"
    puts "Cache from: #{cache_data['generated_at']}"
    puts "Rolling back #{updates_needed.size} forms"
    puts 'Will restore original return_url values'
    puts '=' * 80

    print 'Are you sure you want to rollback these changes? (y/N): '
    confirmation = $stdin.gets.chomp.downcase

    unless confirmation == 'y'
      puts 'Rollback cancelled.'
      exit 0
    end

    rolled_back_count = 0
    error_count = 0
    start_time = Time.current

    updates_needed.each_slice(1000) do |batch_data|
      batch_start_time = Time.current
      batch_rolled_back = 0
      batch_errors = 0

      batch_ids = batch_data.map { |item| item['id'] }
      InProgressForm.where(id: batch_ids).find_each do |form|
        cached_item = batch_data.find { |item| item['id'] == form.id }
        original_return_url = cached_item['original_return_url']

        # Check if this form currently has the new return_url (safety check)
        metadata = form.metadata || {}
        current_return_url = metadata['return_url']

        if current_return_url == new_return_url
          # Restore original value
          metadata['return_url'] = original_return_url
          form.metadata = metadata

          if form.save
            rolled_back_count += 1
            batch_rolled_back += 1
          else
            error_count += 1
            batch_errors += 1
            puts "  Failed to rollback form ID #{form.id}: #{form.errors.full_messages.join(', ')}"
          end
        else
          puts "  Form ID #{form.id} return_url is '#{current_return_url}', expected '#{new_return_url}'"
          error_count += 1
          batch_errors += 1
        end
      rescue => e
        error_count += 1
        batch_errors += 1
        puts "  Error rolling back form ID #{form.id}: #{e.message}"
      end

      batch_time = Time.current - batch_start_time
      puts "Batch completed: #{batch_rolled_back} rolled back, #{batch_errors} errors (#{batch_time.round(2)}s)"
    end

    total_time = Time.current - start_time

    puts
    puts '=' * 80
    puts 'ROLLBACK SUMMARY'
    puts '=' * 80
    puts "Forms processed: #{updates_needed.size}"
    puts "Successfully rolled back: #{rolled_back_count}"
    puts "Errors: #{error_count}"
    puts "Processing time: #{total_time.round(2)} seconds"
    puts

    if rolled_back_count.positive?
      puts "SUCCESS: Rolled back #{rolled_back_count} forms to their original return_url values"
    end

    puts "#{error_count} forms had errors during rollback" if error_count.positive?

    puts "Completed at: #{Time.current}"
    puts '=' * 80
  end
end
