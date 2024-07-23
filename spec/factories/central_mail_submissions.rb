# frozen_string_literal: true

require 'saved_claim/burial'

FactoryBot.define do
  factory :central_mail_submission do
    association :central_mail_claim, factory: :burial_claim
    state { 'success' }
  end
end
