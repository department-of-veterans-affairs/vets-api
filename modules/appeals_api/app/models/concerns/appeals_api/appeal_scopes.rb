# frozen_string_literal: true

module AppealsApi
  module AppealScopes
    extend ActiveSupport::Concern

    included do
      scope :without_status_updates_since, lambda { |time|
        status_update_table = AppealsApi::StatusUpdate.table_name
        join_clause = <<~JOIN
          LEFT JOIN #{status_update_table}
          ON #{table_name}.id = CAST(#{status_update_table}.statusable_id as uuid)
          AND #{status_update_table}.id IS NULL
          AND #{status_update_table}.statusable_type = '#{sanitize_sql(klass.name)}'
        JOIN
        where("#{table_name}.updated_at <= ?", time)
          .where.not(id: joins(join_clause).where("#{status_update_table}.created_at >= ?", time).distinct.pluck(:id))
      }

      scope :with_pii, -> { where.not(form_data_ciphertext: nil).or(where.not(auth_headers_ciphertext: nil)) }

      scope :with_expired_pii, lambda {
        # PII should be removed if...
        # (1) appeal is in any state and the status last changed 45+ days ago, or...
        with_pii.without_status_updates_since(45.days.ago)
                # (2) appeal is in 'complete' or 'success' status and status last changed 7+ days ago, or...
                .or(with_pii.where(table_name => { status: %w[complete success] })
                            .without_status_updates_since(7.days.ago))
                # (3) appeal has 'Unidentified Mail' error and status last changed 7+ days ago.
                .or(with_pii.where(table_name => { status: 'error' })
                            .where(klass.arel_table[:detail].matches('%%Unidentified Mail%%'))
                            .without_status_updates_since(7.days.ago))
      }
    end
  end
end
