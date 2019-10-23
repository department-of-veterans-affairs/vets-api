# frozen_string_literal: true

namespace :va_forms do
  task fetch_latest: :environment do
    VaForms::Form.refresh!
  end
end
