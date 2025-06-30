# frozen_string_literal: true

Rails.root.glob("db/seeds/#{Rails.env}/**/*.rb").sort.each do |file|
  load file
end
