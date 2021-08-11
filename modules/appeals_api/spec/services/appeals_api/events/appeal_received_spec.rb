# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module Events
    RSpec.describe AppealReceived do
      describe 'higher_level_review' do
        it 'errors if the keys needed are missing' do
          opts = {}

          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }.to raise_error(InvalidKeys)
        end

        it 'sends an email' do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          allow(client).to receive(:send_email)

          opts = {
            'email' => 'fake_email@email.com',
            'veteran_first_name' => 'first name',
            'date_submitted' => Time.zone.now.to_date,
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email)
        end
      end
    end
  end
end
