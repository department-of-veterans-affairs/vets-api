# frozen_string_literal: true

FactoryBot.define do
  factory :ar_persistent_attachment_va_form,
    class: 'AccreditedRepresentativePortal::PersistentAttachments::VAForm' do
    form_id { '20-10207' }

    after(:build) do |attachment|
      file = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').open('rb')
      uploaded_file = Shrine.upload(file, :store)
      attachment.file_data = uploaded_file.to_json
    end
  end

  factory :ar_persistent_attachment_va_form_documentation,
    class: 'AccreditedRepresentativePortal::PersistentAttachments::VAFormDocumentation' do
    after(:build) do |attachment|
      file = Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf').open('rb')
      uploaded_file = Shrine.upload(file, :store)
      attachment.file_data = uploaded_file.to_json
    end
  end
end
