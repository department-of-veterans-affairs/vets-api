# frozen_string_literal: true

FactoryBot.define do
  factory :hca_dd214_attachment do
    after(:build) do |hca_dd214_attachment|
      hca_dd214_attachment.set_file_data!(
        Rack::Test::UploadedFile.new(Rails.root.join('spec', 'fixtures', 'preneeds', 'extras.pdf'), 'application/pdf')
      )
    end
  end
end
