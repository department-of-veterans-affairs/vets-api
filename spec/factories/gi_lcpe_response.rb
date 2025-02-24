# frozen_string_literal: true

require 'gi/lcpe/response'

FactoryBot.define do
  factory :gi_lcpe_response, class: 'GI::LCPE::Response' do
    transient do
      v_fresh { '3' }
      v_stale { '2' }
      version { v_fresh }
      lac do
        { enriched_id: "1@#{version}",
          lac_nm: 'Gas Fitter',
          edu_lac_type_nm: 'License',
          state: 'AR' }
      end
    end

    body { { lacs: [lac], version: } }
    status { 200 }

    trait :stale do
      version { v_stale }
    end
  end
end
