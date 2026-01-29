# frozen_string_literal: true

module DecisionReviews
  module V1
    module HigherLevelReviews
      class ContestableIssuesController < AppealsBaseController
        service_tag 'higher-level-review'

        def index
          ci = get_appealable_issues.body
          render json: merge_legacy_appeals(ci)
        rescue => e
          log_exception_to_personal_information_log(
            e,
            error_class: "#{self.class.name}#index exception #{e.class} (HLR_V1)",
            benefit_type: params[:benefit_type]
          )
          raise
        end

        private

        def merge_legacy_appeals(contestable_issues)
          # Fetch Legacy Appels and combine with CIs
          ci_la = nil
          begin
            la = decision_review_service
                 .get_legacy_appeals(user: current_user)
                 .body
            # punch in an empty LA section if no LAs for user to distinguish no LAs from a LA call fail
            la['data'] = [{ type: 'legacyAppeal', attributes: { issues: [] } }] if la['data'].empty?
            ci_la = { data: contestable_issues['data'] + la['data'] }
          rescue => e
            # If LA fails keep going Legacy Appeals are not critical, return original contestable_issues
            log_exception_to_personal_information_log(
              e,
              error_class: "#{self.class.name}#index exception #{e.class} (HLR_V1_LEGACY_APPEALS)",
              benefit_type: params[:benefit_type]
            )
            contestable_issues
          else
            ci_la
          end
        end

        def get_appealable_issues
          if use_new_appealable_issues_service?
            appealable_issues_service
              .get_higher_level_review_issues(user: current_user, benefit_type: params[:benefit_type])
          else
            decision_review_service
              .get_higher_level_review_contestable_issues(user: current_user, benefit_type: params[:benefit_type])
          end
        end
      end
    end
  end
end
