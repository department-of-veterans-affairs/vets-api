# frozen_string_literal: true

require_relative 'base_gateway'

module Forms
  module SubmissionStatuses
    module Gateways
      class IvcChampvaGateway < BaseGateway
        SubmissionAdapter = Struct.new(
          :id,
          :form_type,
          :created_at,
          :updated_at,
          :pega_status,
          keyword_init: true
        )

        FORM_TYPE_MAP = {
          'vha1010d' => '10-10D',
          'vha_10_10d' => '10-10D',
          '10-10d' => '10-10D',
          'vha_10_10d_2027' => '10-10D-EXTENDED',
          '10-10d-extended' => '10-10D-EXTENDED',
          '10-10d-ext' => '10-10D-EXTENDED',
          '10-7959a' => '10-7959A',
          '10-7959c' => '10-7959C',
          'vha_10_7959c' => '10-7959C',
          'vha_10_7959c_rev2025' => '10-7959C',
          '10-7959f-1' => '10-7959F-1',
          '10-7959f-2' => '10-7959F-2'
        }.freeze

        PROCESSED_STATUSES = ['Processed', 'Manually Processed'].freeze
        ERROR_STATUSES = ['Error', 'Failed', 'Rejected', 'Submission failed'].freeze

        def submissions
          submissions_from_forms
        end

        def api_statuses(submissions)
          statuses = submissions.map do |submission|
            normalized_status = normalize_status(submission.pega_status)
            {
              'attributes' => {
                'guid' => submission.id,
                'status' => normalized_status,
                'message' => message_for(normalized_status),
                'detail' => detail_for(submission.pega_status),
                'updated_at' => submission.updated_at
              }
            }
          end

          [statuses, nil]
        end

        private

        def submissions_from_forms
          grouped_records = scoped_forms.order(:created_at).group_by(&:form_uuid)

          grouped_records.values.filter_map do |records|
            representative = records.max_by(&:updated_at)
            form_type = normalize_form_type(representative&.form_number)
            next if allowed_forms.present? && allowed_forms.exclude?(form_type)

            SubmissionAdapter.new(
              id: representative&.form_uuid,
              form_type:,
              created_at: records.min_by(&:created_at)&.created_at,
              updated_at: representative&.updated_at,
              pega_status: representative&.pega_status
            )
          end
        end

        def scoped_forms
          return IvcChampvaForm.none if user_emails.blank?

          IvcChampvaForm.where('LOWER(TRIM(email)) IN (?)', user_emails)
        end

        def user_emails
          verifications = user_account.user_verifications.includes(:user_credential_email)
          @user_emails ||= verifications.filter_map do |verification|
            verification.user_credential_email&.credential_email&.strip&.downcase
          end.uniq
        end

        def normalize_form_type(form_number)
          normalized = form_number.to_s.strip.downcase
          FORM_TYPE_MAP[normalized] || form_number.to_s.upcase
        end

        def normalize_status(pega_status)
          return 'vbms' if PROCESSED_STATUSES.include?(pega_status)
          return 'error' if ERROR_STATUSES.include?(pega_status)

          'pending'
        end

        def message_for(normalized_status)
          case normalized_status
          when 'vbms'
            'Form received'
          when 'error'
            'Action needed'
          else
            'Form submitted'
          end
        end

        def detail_for(pega_status)
          pega_status.presence || 'Pending'
        end
      end
    end
  end
end
