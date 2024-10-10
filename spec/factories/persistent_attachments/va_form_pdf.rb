# frozen_string_literal: true

FactoryBot.define do
  factory :va_form_pdf, class: 'PersistentAttachments::VAForm' do
    transient do
      file_path { nil }
    end

    after(:build) do |va_form, evaluator|
      file_path = evaluator.file_path || 'spec/fixtures/files/doctors-note.pdf'

      va_form.file = File.open(file_path)
    end
  end
end
