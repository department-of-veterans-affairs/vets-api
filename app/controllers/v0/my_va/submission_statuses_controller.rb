# frozen_string_literal: true

require 'forms/submission_statuses/report'

module V0
  module MyVA
    class SubmissionStatusesController < ApplicationController
      service_tag 'form-submission-statuses'

      def show
        report = Forms::SubmissionStatuses::Report.new(
          user_account: @current_user.user_account,
          allowed_forms: forms_based_on_feature_toggle,
          gateway_options: gateway_options_for_user
        )
        result = report.run

        render json: serializable_from(result).to_json, status: status_from(result)
      end

      private

      def restricted_list_of_forms
        forms = []
        # Always include benefits intake forms for backward compatibility
        forms += restricted_benefits_intake_forms
        forms += decision_reviews_forms_if_enabled
        forms
      end

      def restricted_benefits_intake_forms
        %w[
          20-10206
          20-10207
          21-0845
          21-0972
          21-10210
          21-4142
          21-4140
          21-4142a
          21P-0847
          21P-527EZ
          21P-530EZ
          21P-0969
          21P-535
        ] + uploadable_forms
      end

      def decision_reviews_forms_if_enabled
        return [] unless display_decision_reviews_forms?

        # we use form0995_form4142 here to distinguish SC 4142s from standalone 4142s
        %w[
          20-0995
          20-0996
          10182
          form0995_form4142
        ]
      end

      def uploadable_forms
        FormProfile::ALL_FORMS[:form_upload]
      end

      def serializable_from(result)
        hash = SubmissionStatusSerializer.new(result.submission_statuses).serializable_hash
        hash[:errors] = result.errors
        hash
      end

      def status_from(result)
        result.errors.present? ? 296 : 200
      end

      def forms_based_on_feature_toggle
        return nil if display_all_forms?

        restricted_list_of_forms
      end

      def gateway_options_for_user
        {
          # ALWAYS enable benefits intake for backward compatibility
          # The feature flag only controls whether to show ALL forms vs restricted list
          benefits_intake_enabled: true,
          decision_reviews_enabled: display_decision_reviews_forms?
        }
      end

      def display_all_forms?
        # When this flag is true, show ALL forms without restriction (pass nil for allowed_forms)
        # When false, show the restricted list of forms
        Flipper.enabled?(
          :my_va_display_all_lighthouse_benefits_intake_forms,
          @current_user
        )
      end

      def display_decision_reviews_forms?
        Flipper.enabled?(
          :my_va_display_decision_reviews_forms,
          @current_user
        )
      end
    end
  end
end
