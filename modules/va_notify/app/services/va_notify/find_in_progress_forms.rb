# frozen_string_literal: true

module VANotify
  class FindInProgressForms
    RELEVANT_FORMS = %w[
      686C-674
      1010ez
    ].freeze

    def to_notify
      date_range = [
        7.days.ago.beginning_of_day..7.days.ago.end_of_day
      ]

      InProgressForm.where(form_id: RELEVANT_FORMS).where(updated_at: date_range)
                    .order(:created_at).pluck(:id)
    end
  end
end
