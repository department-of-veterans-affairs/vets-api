# frozen_string_literal: true

FactoryBot.define do
  factory :form1010cg_attachment, class: 'Form1010cg::Attachment' do
    trait(:with_attachment) do
      file_data { 'foo' }
    end
  end
end
