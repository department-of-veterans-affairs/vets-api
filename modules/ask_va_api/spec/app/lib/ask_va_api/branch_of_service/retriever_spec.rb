# frozen_string_literal: true

require 'rails_helper'

module AskVAApi
  module BranchOfService
    RSpec.describe Retriever do
      subject(:retriever) { described_class.new(entity_class:, user_mock_data: true) }

      let(:entity_class) { Entity }

      describe '#call' do
        context 'when successful' do
          before do
            allow_any_instance_of(ClaimsApi::BRD).to receive(:service_branches).and_return(
              [{ code: 'USMA', description: 'US Military Academy' },
               { code: 'MM', description: 'Merchant Marine' },
               { code: 'AF', description: 'Air Force' },
               { code: 'ARMY', description: 'Army' },
               { code: 'AFR', description: 'Air Force Reserves' },
               { code: 'PHS', description: 'Public Health Service' },
               { code: 'AAC', description: 'Army Air Corps or Army Air Force' },
               { code: 'WAC', description: "Women's Army Corps" },
               { code: 'NOAA', description: 'National Oceanic & Atmospheric Administration' },
               { code: 'SF', description: 'Space Force' },
               { code: 'NAVY', description: 'Navy' },
               { code: 'N ACAD', description: 'Naval Academy' },
               { code: 'OTH', description: 'Other' },
               { code: 'ARNG', description: 'Army National Guard' },
               { code: 'CG', description: 'Coast Guard' },
               { code: 'MC', description: 'Marine Corps' },
               { code: 'AR', description: 'Army Reserves' },
               { code: 'CGR', description: 'Coast Guard Reserves' },
               { code: 'MCR', description: 'Marine Corps Reserves' },
               { code: 'NR', description: 'Navy Reserves' },
               { code: 'ANG', description: 'Air National Guard' },
               { code: 'AF ACAD', description: 'Air Force Academy' },
               { code: 'CG ACAD', description: 'Coast Guard Academy' }]
            )
          end

          it 'returns a list of the branch of service' do
            expect(retriever.call).to all(be_a(entity_class))
          end
        end
      end
    end
  end
end
