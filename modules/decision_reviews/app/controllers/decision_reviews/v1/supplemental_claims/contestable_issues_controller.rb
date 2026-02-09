# frozen_string_literal: true

module DecisionReviews
  module V1
    module SupplementalClaims
      class ContestableIssuesController < AppealsBaseController
        service_tag 'appeal-application'

        def index
          ci = decision_review_service
               .get_supplemental_claim_contestable_issues(user: current_user, benefit_type: params[:benefit_type])
               .body
          render json: merge_legacy_appeals(ci)
        rescue => e
          log_exception_to_personal_information_log e,
                                                    error_class: "#{self.class.name}#index exception #{e.class} (SC_V1)"
          raise
        end

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
              error_class: "#{self.class.name}#index exception #{e.class} (SC_V1_LEGACY_APPEALS)",
              benefit_type: params[:benefit_type]
            )
            contestable_issues
          else
            ci_la
          end
        end
      end
    end
  end
end
