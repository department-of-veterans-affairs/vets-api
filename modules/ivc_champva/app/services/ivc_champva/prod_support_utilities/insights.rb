# frozen_string_literal: true

# This can be used to get some statistics about the number of
# users with resubmissions to IVC forms.

module IvcChampva
  module ProdSupportUtilities
    # rubocop:disable Rails/Output
    class Insights
      # TODO: add docstrings
      def count_batches_by_email_grouped(days_ago = 7, gate = 2, form_number = '10-10D')
        puts "#{form_number} submits over the last #{days_ago} days:"
        # Get the current date and time
        end_date = Time.zone.now
        start_date = end_date - days_ago.days

        # Grab count of individual submissions made per unique email (a submission means
        # a single form submit and all supporting docs associated)
        submissions = IvcChampvaForm
                      .where(created_at: start_date..end_date)
                      .where(form_number:)
                      .select('email, COUNT(DISTINCT form_uuid) AS unique_submission_count')
                      .group(:email)

        # Clean up the result into a hash mapping emails to counts of submissions
        # e.g.: {'name@mail.com' => 1, 'name2@mail.com' => 5}
        submissions = submissions.to_h { |r| [r.email, r.unique_submission_count] }

        # Count keys to give us the total number of unique individuals via their emails
        unique_individuals = submissions.keys.count.to_f
        puts "\n#{unique_individuals} unique email addresses"

        # Identify those who submitted more than `gate` times
        multi_submits = submissions.reject { |_key, value| value < gate }
        emails_with_multi_submits = multi_submits.keys.count.to_f
        puts "#{emails_with_multi_submits} unique email addresses associated with repeat submissions"

        percentage = (emails_with_multi_submits / unique_individuals) * 100
        puts "#{percentage.round(2)}% of submitters have #{gate} or more submissions\n--"
        # Show breakdown of how many of each volume of submits we get
        freq = count_frequency(submissions)
        display_frequency(freq)
        display_averages(submissions, start_date, end_date, gate, form_number)

        nil
      end

      private

      def average_time_between_resubmissions(submissions, start_date, end_date, num_of_resubmits, form_number)
        all_time_differences = []

        # all user email addresses associated with exactly n unique submits
        resubmits = submissions.select { |_key, value| value == num_of_resubmits }

        resubmits.each_key do |email|
          # For each user and form_uuid pair, calculate the time differences between their submissions
          time_differences = []
          # Find all submissions for this user and form_uuid, ordered by submission time
          user_batches = get_user_batches_in_window(email, start_date, end_date, form_number)
          # Step 3: Calculate time differences between successive submissions
          previous_submission_time = nil
          user_batches.each_value do |batch|
            submission = batch[0]
            if previous_submission_time
              # Calculate time difference in seconds
              time_diff = submission.created_at - previous_submission_time
              # Ensure we use the absolute difference so we don't get negative times
              time_diff *= -1 if time_diff.negative?
              # Store to calculate average later
              time_differences << time_diff
            end
            previous_submission_time = submission.created_at
          end

          next if time_differences.empty?

          all_time_differences << (time_differences.sum / time_differences.size)
        end

        # return average of all averages for users with n resubmits
        return nil if all_time_differences.empty? # Avoid division by zero

        all_time_differences.sum / all_time_differences.size
      end

      def get_user_batches_in_window(email_addr, start_date, end_date, form_number)
        results = IvcChampvaForm.where(email: email_addr)
                                .where(form_number:)
                                .where(created_at: start_date..end_date)

        # Return the results grouped into batches by form_uuid
        missing_status_cleanup.batch_records(results)
      end

      def count_frequency(submitters)
        submitters.each.with_object(Hash.new(0)) do |num_submissions, result_hash|
          result_hash[num_submissions] += 1
        end
      end

      def display_frequency(freq_hash)
        # Make sure hash is sorted by key:
        descending = freq_hash.sort_by(&:first).reverse.to_h

        descending.each do |num_submissions, quantity|
          puts "Number of users with #{num_submissions} submissions: #{quantity}" unless num_submissions == 1
        end

        nil
      end

      def display_averages(submissions, start_date, end_date, _gate, form_number)
        # Make sure hash is sorted by key:
        descending = submissions.sort_by(&:last).reverse.to_h

        unique_nums = descending.values.uniq

        unique_nums.each do |num_submissions|
          next unless num_submissions > 1

          avg_time = average_time_between_resubmissions(submissions, start_date, end_date, num_submissions,
                                                        form_number)
          avg_time = avg_time.nil? ? nil : make_time_str(avg_time)
          puts "Avg time between resubmits for users with #{num_submissions} submissions: #{avg_time}"
        end

        nil
      end

      def make_time_str(duration_seconds)
        ActiveSupport::Duration.build(duration_seconds).parts.map do |key, value|
          [value.to_i, ' ', key].join
        end.join(', ')
      end

      def missing_status_cleanup
        IvcChampva::ProdSupportUtilities::MissingStatusCleanup.new
      end
      # rubocop:enable Rails/Output
    end
  end
end
