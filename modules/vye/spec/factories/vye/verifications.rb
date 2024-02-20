# frozen_string_literal: true

FactoryBot.define do
  factory :vye_verification, class: 'Vye::Verification' do
    source_ind { Vye::Verification.source_inds.values.sample }
  end
end
