# frozen_string_literal: true

module ClaimsApi
  class BGSToLighthouseClaimsMapperService < ClaimsApi::Service
    attr_accessor :bgs_claim, :lighthouse_claim

    def initialize(bgs_claim: nil, lighthouse_claim: nil)
      @bgs_claim        = bgs_claim
      @lighthouse_claim = lighthouse_claim
    end

    def process
      return matched_claim if bgs_and_lighthouse_claims_exist?
      return unmatched_bgs_claim if bgs_claim_only?
      return unmatched_lighthouse_claim if lighthouse_claim_only?

      {}
    end

    private

    def bgs_and_lighthouse_claims_exist?
      bgs_claim.present? && lighthouse_claim.present?
    end

    def bgs_claim_only?
      bgs_claim.present? && lighthouse_claim.blank?
    end

    def lighthouse_claim_only?
      bgs_claim.blank? && lighthouse_claim.present?
    end

    def matched_claim
      # this claim was submitted via Lighthouse, so use the 'id' the user is most likely to know
      {
        id: lighthouse_claim.id,
        type: bgs_claim[:claim_status_type],
        date_filed: bgs_claim[:claim_dt],
        status: bgs_claim[:phase_type],
        end_product_code: bgs_claim[:end_product_code],
        documents_needed: bgs_claim[:attention_needed],
        requested_decision: map_y_n_to_boolean('filed5103_waiver_ind', bgs_claim[:filed5103_waiver_ind]),
        development_letter_sent: map_yes_no_to_boolean('development_letter_sent', bgs_claim[:development_letter_sent]),
        decision_letter_sent: map_yes_no_to_boolean('decision_notification_sent',
                                                    bgs_claim[:decision_notification_sent])
      }
    end

    def unmatched_bgs_claim
      {
        id: bgs_claim[:benefit_claim_id],
        type: bgs_claim[:claim_status_type],
        date_filed: bgs_claim[:claim_dt],
        status: bgs_claim[:phase_type],
        end_product_code: bgs_claim[:end_product_code],
        documents_needed: map_yes_no_to_boolean('attention_needed', bgs_claim[:attention_needed]),
        requested_decision: map_y_n_to_boolean('filed5103_waiver_ind', bgs_claim[:filed5103_waiver_ind]),
        development_letter_sent: map_yes_no_to_boolean('development_letter_sent', bgs_claim[:development_letter_sent]),
        decision_letter_sent: map_yes_no_to_boolean('decision_notification_sent',
                                                    bgs_claim[:decision_notification_sent])
      }
    end

    def unmatched_lighthouse_claim
      { id: lighthouse_claim.id, type: lighthouse_claim.claim_type, status: lighthouse_claim.status.capitalize }
    end

    def map_yes_no_to_boolean(key, value)
      return nil if value.blank?

      case value.downcase
      when 'yes' then true
      when 'no' then false
      else
        Rails.logger.error "Expected key '#{key}' to be Yes/No. Got '#{s}'."
        nil
      end
    end

    def map_y_n_to_boolean(key, value)
      return nil if value.blank?

      case value.downcase
      when 'y' then true
      when 'n' then false
      else
        Rails.logger.error "Expected key '#{key}' to be Y/N. Got '#{s}'."
        nil
      end
    end
  end
end
