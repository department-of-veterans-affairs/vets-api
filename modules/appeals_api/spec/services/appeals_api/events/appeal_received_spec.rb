# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module Events
    RSpec.describe AppealReceived do
      describe 'higher_level_review' do
        it 'errors if the keys needed are missing' do
          opts = {}

          expect { AppealsApi::Events::AppealReceived.new(opts).higher_level_review }.to raise_error(InvalidKeys)
        end

        it 'creates a status update' do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          allow(client).to receive(:send_email)


          opts = {
            'email' => 'fake_email@email.com'
          }


          AppealsApi::Events::AppealReceived.new(opts).higher_level_review

          expect(client).to have_received(:send_email)
        end
      end
    end
  end
end
