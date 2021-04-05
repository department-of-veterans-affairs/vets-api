# frozen_string_literal: true

FactoryBot.define do
  factory :communication_permission, class: 'VAProfile::Models::CommunicationPermission' do
    allowed { false }
  end
end
