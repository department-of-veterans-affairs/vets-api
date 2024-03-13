# frozen_string_literal: true

namespace :va_forms do
  task migrate_form_change_history_from_paper_trail: :environment do
    VAForms::Form.find_each do |form|
      form_versions = form.versions.order(created_at: :asc)

      if form_versions.present?
        form.last_sha256_change = form_versions.last&.created_at
        form.change_history = {}
        form.change_history['versions'] = form_versions.map do |v|
          if v.changeset.present?
            {
              sha256: v.changeset['sha256']&.last,
              revision_on: v.created_at&.strftime('%Y-%m-%d')
            }
          end
        end
        form.save!
      end
    end
  end
end
