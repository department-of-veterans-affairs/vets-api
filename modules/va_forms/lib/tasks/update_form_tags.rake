# frozen_string_literal: true

module VAForms
  module UpdateFormTags
    module_function

    def run
      ActiveRecord::Base.transaction do
        ActiveRecord::Base.connection.execute("
        UPDATE va_forms_forms SET tags = concat(concat(tags, ' ') , REPLACE(form_name , '-', '') )
      ")
      end
    end
  end
end

namespace :va_forms do
  task update_form_tags: :environment do
    VAForms::UpdateFormTags.run
  end
end
