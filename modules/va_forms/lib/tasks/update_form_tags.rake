# frozen_string_literal: true

namespace :va_forms do
  task update_form_tags: :environment do
    VAForms::UpdateFormTagsService.run
  end
end
