# frozen_string_literal: true

FactoryBot.define do
  factory :persistent_attachment do
    guid { Faker::Internet.uuid }

    after(:build) do |attachment|
      file = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').open('rb')
      uploaded_file = Shrine.upload(file, :store)
      attachment.file_data = uploaded_file.to_json
    end

    factory :persistent_attachment_va_form, class: 'PersistentAttachments::VAForm' do
      form_id { '20-10207' }

      after(:build) do |attachment|
        file = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').open('rb')
        uploaded_file = Shrine.upload(file, :store)
        attachment.file_data = uploaded_file.to_json
      end
    end

    factory :persistent_attachment_va_form_documentation, class: 'PersistentAttachments::VAFormDocumentation' do
      after(:build) do |attachment|
        file = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').open('rb')
        uploaded_file = Shrine.upload(file, :store)
        attachment.file_data = uploaded_file.to_json
      end
    end
  end
end
