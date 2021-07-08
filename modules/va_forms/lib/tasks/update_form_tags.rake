# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
module VAForms
  module UpdateFormTags
    module_function

    # rubocop:disable Metrics/MethodLength
    def run
      ActiveRecord::Base.transaction do
        # rubocop:disable Layout/LineLength
        ActiveRecord::Base.connection.execute("
        UPDATE va_forms_forms SET tags = concat(concat(tags, ' ') , REPLACE(form_name , '-', '') )
      ")
        # rubocop:enable Layout/LineLength
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end

namespace :va_forms do
  task update_form_tags: :environment do
    VAForms::UpdateFormTags.run
  end
end
# rubocop:enable Metrics/BlockLength
