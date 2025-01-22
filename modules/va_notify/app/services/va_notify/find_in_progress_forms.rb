# frozen_string_literal: true

module VANotify
  class FindInProgressForms
    RELEVANT_FORMS = %w[
      686C-674
      1010ez
      21-526EZ
    ].freeze

    def to_notify
      date_range = [
        7.days.ago.all_day
      ]

      InProgressForm.where(form_id: RELEVANT_FORMS).where(updated_at: date_range)
                    .order(:created_at).pluck(:id)
    end
  end
end
