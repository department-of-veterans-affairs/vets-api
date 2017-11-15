# frozen_string_literal: true
FactoryGirl.define do
  factory :preneed_attachment_hash, class: Preneeds::PreneedAttachmentHash do
    confirmation_code { create(:preneed_attachment).guid }
    attachment_id('1')
  end
end
