# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module AppealsApi
  module Events
    RSpec.describe AppealReceived do
      describe 'higher_level_review' do
        it 'errors if the keys needed are missing' do
          opts = {}
          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }
            .to raise_error(InvalidKeys, 'AppealReceived: Missing required keys')
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
          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }
            .to raise_error(InvalidKeys, 'Invalid email identifier')
        end

        it 'errors if the template id cannot be found' do
          error_prefix = 'AppealReceived: could not find template id for'

          opts = {
            'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
            'first_name' => 'first name',
            'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
            'guid' => '1234556',
            'claimant_email' => '',
            'claimant_first_name' => ''
          }

          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }
            .to raise_error(InvalidTemplateId, "#{error_prefix} higher_level_review_received")

          opts['claimant_email'] = 'fake_claimant_email@email.com'
          opts['claimant_first_name'] = 'Betty'
          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }
            .to raise_error(InvalidTemplateId, "#{error_prefix} higher_level_review_received_claimant")
        end

        it 'sends an email' do
          with_settings(Settings.vanotify.services.lighthouse.template_id,
                        higher_level_review_received: 'veteran_template',
                        higher_level_review_received_claimant: 'claimant_template') do
            client = instance_double(VaNotify::Service)
            allow(VaNotify::Service).to receive(:new).and_return(client)
            allow(client).to receive(:send_email)

            opts = {
              'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
              'first_name' => 'first name',
              'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
              'guid' => '1234556',
              'claimant_email' => '',
              'claimant_first_name' => ''
            }

            AppealsApi::Events::AppealReceived.new(opts).hlr_received

            expect(client).to have_received(:send_email).with(
              {
                email_address: 'fake_email@email.com',
                template_id: 'veteran_template',
                personalisation: {
                  'first_name' => 'first name',
                  'date_submitted' => 'January 02, 2021'
                }
              }
            )
          end
        end

        it 'does not care about the order of email identifier hash' do
          with_settings(Settings.vanotify.services.lighthouse.template_id,
                        higher_level_review_received: 'veteran_template',
                        higher_level_review_received_claimant: 'claimant_template') do
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
                template_id: 'veteran_template',
                personalisation: {
                  'first_name' => 'first name',
                  'date_submitted' => 'January 02, 2021'
                }
              }
            )
          end
        end

        it 'sends email to claimant using the claimant template' do
          with_settings(
            Settings.vanotify.services.lighthouse.template_id,
            higher_level_review_received: 'veteran_template',
            higher_level_review_received_claimant: 'claimant_template'
          ) do
            client = instance_double(VaNotify::Service)
            allow(VaNotify::Service).to receive(:new).and_return(client)
            allow(client).to receive(:send_email)

            opts = {
              'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
              'first_name' => 'veteran first name',
              'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
              'guid' => '1234556',
              'claimant_email' => 'fake_claimant_email@email.com',
              'claimant_first_name' => 'Betty'
            }

            AppealsApi::Events::AppealReceived.new(opts).hlr_received

            expect(client).to have_received(:send_email).with(
              {
                email_address: 'fake_claimant_email@email.com',
                template_id: 'claimant_template',
                personalisation: {
                  'first_name' => 'Betty',
                  'date_submitted' => 'January 02, 2021',
                  'veterans_name' => 'veteran first name'
                }
              }
            )
          end
        end

        it 'raises if claimant info is missing email' do
          opts = {
            'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
            'first_name' => 'first name',
            'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
            'guid' => '1234556',
            'claimant_email' => '   ', # Blank email
            'claimant_first_name' => 'Betty'
          }

          expect { AppealsApi::Events::AppealReceived.new(opts).hlr_received }
            .to raise_error(InvalidKeys, 'Invalid email identifier')
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
# rubocop:enable Metrics/ModuleLength
