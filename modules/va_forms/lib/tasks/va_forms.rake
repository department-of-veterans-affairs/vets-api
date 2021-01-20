# frozen_string_literal: true

namespace :va_forms do
  task fetch_latest: :environment do
    VAForms::FormReloader.new.perform
  end

  task fetch_latest_curl: :environment do
    VAForms::FormReloader.new.perform_curl
  end

end
