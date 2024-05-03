# frozen_string_literal: true

FactoryBot.define do
  factory :vye_bdn_clone, class: 'Vye::BdnClone' do
    is_active { true }
    export_ready { false }
  end
end
