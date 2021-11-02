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

        it 'logs error if email identifier cannot be used' do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          opts = {
            'email_identifier' => { 'id_value' => 'fake_email@email.com' }, # missing id_type
            'first_name' => 'first name',
            'date_submitted' => DateTime.new(2021, 11, 11, 1, 2, 3).iso8601,
            'guid' => '1234556'
          }

          expect(Rails.logger).to receive(:error)
          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }.to raise_error(InvalidKeys)
        end

        it 'sends an email' do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          allow(client).to receive(:send_email)

          opts = {
            'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
            'first_name' => 'first name',
            'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email).with(
            {
              email_address: 'fake_email@email.com',
              template_id: nil,
              personalisation: {
                'first_name' => 'first name',
                'date_submitted' => 'January 02, 2021'
              }
            }
          )
        end

        it 'does not care about the order of email identifier hash' do
          client = instance_double(VaNotify::Service)
          allow(VaNotify::Service).to receive(:new).and_return(client)
          allow(client).to receive(:send_email)

          opts = {
            'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
            'first_name' => 'first name',
            'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email).with(
            {
              email_address: 'fake_email@email.com',
              template_id: nil,
              personalisation: {
                'first_name' => 'first name',
                'date_submitted' => 'January 02, 2021'
              }
            }
          )
        end
      end

      it 'uses icn if email isn\'t present' do
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
            'date_submitted' => DateTime.new(1900, 1, 2, 3, 4, 5).iso8601,
            'guid' => '1234556'
          }

          AppealsApi::Events::AppealReceived.new(opts).hlr_received

          expect(client).to have_received(:send_email).with(
            {
              recipient_identifier: {
                id_value: '1233445353',
                id_type: 'ICN'
              },
              template_id: 'fake_template_id',
              personalisation: {
                'first_name' => 'first name',
                'date_submitted' => 'January 02, 1900'
              }
            }
          )
        end
      end
    end
  end
end
