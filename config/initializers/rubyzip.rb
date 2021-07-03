# frozen_string_literal: true

require 'zip'

Rails.application.reloader.to_prepare do
  Zip.continue_on_exists_proc = true
end
