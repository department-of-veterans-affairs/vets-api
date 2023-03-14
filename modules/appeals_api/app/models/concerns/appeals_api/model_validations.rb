# frozen_string_literal: true

module AppealsApi
  module ModelValidations
    extend ActiveSupport::Concern
    # Assumes the model is using claimant and veteran Appellant setup

    module ClassMethods
      attr_accessor :required_nvc_headers

      def required_claimant_headers(headers)
        self.required_nvc_headers = headers
      end
    end

    # rubocop:disable Metrics/BlockLength
    included do
      # validation (header)
      def veteran_birth_date_is_in_the_past
        # don't add more errors to veteran birth date if one already exists
        return if errors.any? { |e| e.options.dig(:source, :header) == 'X-VA-Birth-Date' }
        return unless veteran_birth_date
        return if self.class.past?(veteran_birth_date)

        add_date_error '', veteran_birth_date, source: { header: 'X-VA-Birth-Date' }
      end

      # validation (header)
      def claimant_birth_date_is_in_the_past
        # don't add more errors to claimant birth date if one already exists
        return if errors.any? { |e| e.options.dig(:source, :header) == 'X-VA-NonVeteranClaimant-Birth-Date' }
        return if claimant.birth_date.blank? || self.class.past?(claimant.birth_date)

        add_date_error '', claimant.birth_date, source: { header: 'X-VA-NonVeteranClaimant-Birth-Date' }
      end

      # validation (header & body)
      # Schemas take care of most of the requirements, but we need to check that both header & body data is provided
      def required_claimant_data_is_present
        # Claimant First Name is always required if they've supplied any claimant headers
        has_claimant_headers = claimant.first_name.present?
        # form data that includes a claimant is also sufficient to know it's passed the schema
        has_claimant_data = data_attributes&.fetch('claimant', nil).present?

        return if !has_claimant_headers && !has_claimant_data # No claimant headers or data? not a problem!
        return if has_claimant_headers && has_claimant_data # Has both claimant headers and data? A-ok!

        unless has_claimant_headers
          errors.add '',
                     "'/data/attributes/claimant' field was provided, but missing non-veteran claimant headers",
                     source: { header: '' }, # Blank header source since multiple are missing
                     error_tpath: 'common.exceptions.detailed_schema_errors.required',
                     meta: {
                       missing_fields: self.class.required_nvc_headers
                     }
        end

        unless has_claimant_data
          errors.add '/data/attributes',
                     'Non-veteran claimant headers were provided but missing \'/data/attributes/claimant\' field',
                     error_tpath: 'common.exceptions.detailed_schema_errors.required',
                     meta: { missing_fields: ['claimant'] }
        end
      end

      # validation (body)
      def contestable_issue_dates_are_in_the_past
        # don't add any more errors to issue dates if one already exists
        return if errors.any? { |e| e.attribute =~ /decisionDate/ }
        return if contestable_issues.blank?

        contestable_issues.each_with_index do |issue, index|
          decision_date_not_in_past(issue, index)
        end
      end

      def decision_date_not_in_past(issue, issue_index)
        return if issue.decision_date.nil? || issue.decision_date_past?

        add_date_error "/data/included[#{issue_index}]/attributes/decisionDate", issue.decision_date
      end

      # validation (body)
      def validate_retrieve_from_date_range
        return if evidence_submission['retrieveFrom'].nil?

        evidence_submission['retrieveFrom'].each_with_index do |retrieval_evidence, evidence_index|
          retrieval_evidence['attributes']['evidenceDates'].each_with_index do |evidence_date, date_index|
            schema_pointer = "/data/attributes/evidenceSubmission/retrieveFrom[#{evidence_index}]/attributes/evidenceDates[#{date_index}]" # rubocop:disable Layout/LineLength
            start_date_str = evidence_date['startDate']
            end_date_str = evidence_date['endDate']

            start_date = Date.parse(start_date_str)
            end_date = Date.parse(end_date_str)

            valid_date_ranges = start_date <= end_date && start_date < Time.zone.today && end_date < Time.zone.today

            add_date_range_error(schema_pointer, start_date, end_date) unless valid_date_ranges
          end
        end
      end

      def add_date_error(pointer, date_str, error_opts = {})
        errors.add pointer,
                   "Date must be in the past: #{date_str}",
                   **error_opts.merge(error_tpath: 'common.exceptions.detailed_schema_errors.range')
      end

      def add_date_range_error(pointer, start_date, end_date, error_opts = {})
        errors.add pointer,
                   "#{start_date} must before or the same day as #{end_date}. Both dates must also be in the past.",
                   **error_opts.merge(error_tpath: 'common.exceptions.detailed_schema_errors.range')
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
