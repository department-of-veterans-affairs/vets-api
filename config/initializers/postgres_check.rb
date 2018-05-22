# frozen_string_literal: true

if Rails.env.development?
  pg_version = ActiveRecord::Base.connection.select_value('SHOW server_version')
  raise 'vets-api requires postgresql version 9.5' unless pg_version =~ /9.5.\d+/
end
