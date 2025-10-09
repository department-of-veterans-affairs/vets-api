# frozen_string_literal: true

# This can be used to get some statistics about the number of
# users with resubmissions to IVC forms.

module IvcChampva
  module ProdSupportUtilities
    # rubocop:disable Rails/Output
    class Insights
      ##
      # Counts the number of batches by email grouped by the number of submissions
      #
      # @param [Integer] days_ago The number of days to look back
      # @param [Integer] gate The number of submissions to consider a multi-submit
      # @param [String] form_number The form number to look at
      #
      # @return [Hash] A hash of metrics
      def count_batches_by_email_grouped(days_ago = 7, gate = 2, form_number = '10-10D')
        puts "#{form_number} submits over the last #{days_ago} days:"

        metrics = gather_submission_metrics(days_ago, gate, form_number)

        puts "\n#{metrics[:unique_individuals]} unique email addresses"
        puts "#{metrics[:emails_with_multi_submits]} unique email addresses associated with repeat submissions"
        puts "#{metrics[:percentage]}% of submitters have #{gate} or more submissions\n--"

        display_frequency(metrics[:frequency_data])
        display_averages_from_data(metrics[:average_time_data])

        nil
      end

      # Returns the same metrics as count_batches_by_email_grouped but as data instead of printing
      def gather_submission_metrics(days_ago = 7, gate = 2, form_number = '10-10D')
        submissions_by_email = get_submissions_by_email(days_ago, form_number)
        basic_stats = calculate_basic_statistics(submissions_by_email, gate)
        frequency_data = get_frequency_data(submissions_by_email)
        average_time_data = get_average_time_data(submissions_by_email, days_ago, form_number)

        {
          form_number:,
          days_ago:,
          gate:,
          unique_individuals: basic_stats[:unique_individuals],
          emails_with_multi_submits: basic_stats[:emails_with_multi_submits],
          percentage: basic_stats[:percentage],
          frequency_data:,
          average_time_data:,
          submissions_by_email:
        }
      end

      private

      def get_submissions_by_email(days_ago, form_number)
        end_date = Time.zone.now
        start_date = end_date - days_ago.days

        submissions = IvcChampvaForm
                      .where(created_at: start_date..end_date)
                      .where(form_number:)
                      .select('email, COUNT(DISTINCT form_uuid) AS unique_submission_count')
                      .group(:email)

        submissions.to_h { |r| [r.email, r.unique_submission_count] }
      end

      def calculate_basic_statistics(submissions_by_email, gate)
        unique_individuals = submissions_by_email.keys.count.to_f
        multi_submits = submissions_by_email.reject { |_key, value| value < gate }
        emails_with_multi_submits = multi_submits.keys.count.to_f
        percentage = (emails_with_multi_submits / unique_individuals) * 100

        {
          unique_individuals: unique_individuals.to_i,
          emails_with_multi_submits: emails_with_multi_submits.to_i,
          percentage: percentage.round(2)
        }
      end

      def get_frequency_data(submissions_by_email)
        frequency_hash = count_frequency(submissions_by_email)
        frequency_hash.sort_by(&:first).reverse.to_h
      end

      def get_average_time_data(submissions_by_email, days_ago, form_number)
        end_date = Time.zone.now
        start_date = end_date - days_ago.days

        # Get unique submission counts and calculate averages for each
        unique_nums = submissions_by_email.values.uniq.select { |num| num > 1 }

        timing_data = unique_nums.map do |num_submissions|
          avg_time_seconds = average_time_between_resubmissions(submissions_by_email, start_date, end_date,
                                                                num_submissions, form_number)
          avg_time_str = avg_time_seconds.nil? ? nil : make_time_str(avg_time_seconds)

          {
            num_submissions:,
            avg_time_seconds:,
            avg_time_formatted: avg_time_str
          }
        end

        timing_data.sort_by { |data| data[:num_submissions] }.reverse
      end

      # rubocop:disable Layout/LineLength
      def display_averages_from_data(average_time_data)
        average_time_data.each do |data|
          puts "Avg time between resubmits for users with #{data[:num_submissions]} submissions: #{data[:avg_time_formatted]}"
        end

        nil
      end
      # rubocop:enable Layout/LineLength

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
        submitters.each.with_object(Hash.new(0)) do |(_, num_submissions), result_hash|
          result_hash[num_submissions] += 1
        end
      end

      def display_frequency(freq_hash)
        freq_hash.each do |num_submissions, quantity|
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
