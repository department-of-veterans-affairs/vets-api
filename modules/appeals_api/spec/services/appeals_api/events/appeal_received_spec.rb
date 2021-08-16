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
            'email_identifier' => { 'id_value' => 'fake_email@email.com' },
            'first_name' => 'first name',
            'date_submitted' => Time.zone.now.to_date,
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email)
        end
      end

      it 'uses icn if email isnt present' do
        with_settings(
          Settings.vanotify.services.lighthouse.template_id,
          higher_level_review_received: 'fake_template_id'
        ) do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          allow(client).to receive(:send_email)

          opts = {
            'email_identifier' => { 'id_value' => '1233445353', 'id_type' => 'ICN' },
            'first_name' => 'first name',
            'date_submitted' => Date.new(1900, 1, 1),
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email).with(
            {
              :recipient_identifier => {
                id_value: '1233445353',
                id_type: 'ICN'
              },
              :template_id => 'fake_template_id',
              'first_name' => 'first name',
              'date_submitted' => 'January 01, 1900'
            }
          )
        end
      end
    end
  end
end
