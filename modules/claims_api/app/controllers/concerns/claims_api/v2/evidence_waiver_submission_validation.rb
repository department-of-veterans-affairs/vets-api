# frozen_string_literal: false

module ClaimsApi
  module V2
    module EvidenceWaiverSubmissionValidation
      def validate_form_5103_submission_values(params)
        form_attributes = params['data']['attributes']
        validate_data(form_attributes)
        # collect errors and pass back to the controller
        raise_error_collection if @errors
      end

      private

      def validate_data(form_attributes)
        return if form_attributes['trackedItemIds'].blank?

        ids = form_attributes['trackedItemIds']

        if ids.none?(Integer)
          collect_error_messages(
            source: '/trackedItemIds',
            detail: 'If trackedItemIds are present, they must be in an array of integers.'
          )
        end
      end

      def errors_array
        @errors ||= []
      end

      def collect_error_messages(detail: 'Missing or invalid attribute', source: '/',
                                 title: 'Unprocessable Entity', status: '422')
        errors_array.push({ detail:, source:, title:, status: })
      end

      def raise_error_collection
        errors_array.uniq! { |e| e[:detail] }
        errors_array
      end
    end
  end
end
