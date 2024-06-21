# frozen_string_literal: true

module ClaimsApi
  module Concerns
    module ClaimBase
      extend ActiveSupport::Concern

      PHASE_MAPPING = {
        'claim received' => 1,
        'under review' => 2,
        'gathering of evidence' => 3,
        'review of evidence' => 4,
        'preparation for decision' => 5,
        'pending decision approval' => 6,
        'preparation for notification' => 7,
        'complete' => 8
      }.freeze

      included do
        attributes :evss_id, :open, :waiver_submitted,
                   :requested_decision, :claim_type

        attribute :updated_at, if: proc { |record| !record.updated_at.nil? }

        attribute :date_filed do |object|
          parse_date(object, 'date')
        end

        attribute :min_est_date do |object|
          parse_date(object, 'min_est_claim_date')
        end

        attribute :max_est_date do |object|
          parse_date(object, 'max_est_claim_date')
        end

        attribute :development_letter_sent do |object|
          parse_yes_no(object, 'development_letter_sent')
        end

        attribute :decision_letter_sent do |object|
          parse_yes_no(object, 'decision_notification_sent')
        end

        attribute :documents_needed do |object|
          parse_yes_no(object, 'attention_needed')
        end

        attribute :open do |object|
          object_data(object)['claim_complete_date'].blank?
        end

        attribute :requested_decision do |object|
          object.requested_decision || object_data(object)['waiver5103_submitted']
        end

        attribute :waiver_submitted do |object|
          object.requested_decision || object_data(object)['waiver5103_submitted']
        end

        attribute :claim_type do |object|
          object_data(object)['status_type']
        end
      end

      class_methods do
        def phase_from_keys(object, *keys)
          s = object_data(object).dig(*keys)&.downcase
          PHASE_MAPPING[s]
        end

        def parse_date(object, *keys, format: '%m/%d/%Y')
          date = object_data(object).dig(*keys)
          date ? Date.strptime(date, format) : nil
        end

        def parse_yes_no(object, *keys)
          s = object_data(object).dig(*keys)
          case s&.downcase
          when 'yes' then true
          when 'no' then false
          else
            Rails.logger.error "Expected key '#{keys.join('/')}' to be Yes/No. Got '#{s}'."
            nil
          end
        end
      end
    end
  end
end
