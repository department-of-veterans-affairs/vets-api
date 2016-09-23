# frozen_string_literal: true
FactoryGirl.define do
  factory :message_draft, parent: :message, class: MessageDraft do
    factory :message_draft_for_model, parent: :message_for_model do
    end
  end
end
