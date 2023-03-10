# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::AppealReceivedJob, type: :job do
  let(:job) { described_class.new }
  let(:client) { instance_double(VaNotify::Service) }

  before do
    allow(VaNotify::Service).to receive(:new).and_return(client)
    allow(client).to receive(:send_email)
  end

  describe 'va notify vet email templates' do
    let(:opts) do
      {
        'receipt_event' => '',
        'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
        'guid' => '1234556'
      }
    end

    it 'uses hlr email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    higher_level_review_received: 'hlr_veteran_template') do
        opts.merge!('receipt_event' => 'hlr_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment(AppealsApi::AppealReceivedJob::STATSD_CLAIMANT_EMAIL_SENT,
                                       tags: ['appeal_type:hlr', 'claimant_type:veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'hlr_veteran_template'))
      end
    end

    it 'uses nod email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    notice_of_disagreement_received: 'nod_veteran_template') do
        opts.merge!('receipt_event' => 'nod_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment('api.appeals.received.claimant.email.sent',
                                       tags: ['appeal_type:nod', 'claimant_type:veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'nod_veteran_template'))
      end
    end

    it 'uses sc email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    supplemental_claim_received: 'sc_veteran_template') do
        opts.merge!('receipt_event' => 'sc_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment('api.appeals.received.claimant.email.sent',
                                       tags: ['appeal_type:sc', 'claimant_type:veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'sc_veteran_template'))
      end
    end
  end

  describe 'va notify claimant email templates' do
    let(:opts) do
      {
        'receipt_event' => '',
        'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
        'guid' => '1234556',
        'claimant_email' => 'fc@email.com',
        'claimant_first_name' => 'AshJoeSue'
      }
    end

    it 'uses hlr email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    higher_level_review_received_claimant: 'hlr_claimant_template') do
        opts.merge!('receipt_event' => 'hlr_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment(AppealsApi::AppealReceivedJob::STATSD_CLAIMANT_EMAIL_SENT,
                                       tags: ['appeal_type:hlr', 'claimant_type:non-veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'hlr_claimant_template'))
      end
    end

    it 'uses nod email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    notice_of_disagreement_received_claimant: 'nod_claimant_template') do
        opts.merge!('receipt_event' => 'nod_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment(AppealsApi::AppealReceivedJob::STATSD_CLAIMANT_EMAIL_SENT,
                                       tags: ['appeal_type:nod', 'claimant_type:non-veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'nod_claimant_template'))
      end
    end

    it 'uses sc email template' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    supplemental_claim_received_claimant: 'sc_claimant_template') do
        opts.merge!('receipt_event' => 'sc_received')
        expect { job.perform(opts) }
          .to trigger_statsd_increment(AppealsApi::AppealReceivedJob::STATSD_CLAIMANT_EMAIL_SENT,
                                       tags: ['appeal_type:sc', 'claimant_type:non-veteran'], times: 1)
        expect(client).to have_received(:send_email).with(hash_including(template_id: 'sc_claimant_template'))
      end
    end
  end

  describe 'higher_level_review' do
    it 'errors if the keys needed are missing' do
      opts = {
        'receipt_event' => 'hlr_received'
      }
      expect(Rails.logger).to receive(:error).with 'AppealReceived: Missing required keys'
      expect(client).not_to have_received(:send_email)

      job.perform(opts)
    end

    it 'logs error if email identifier cannot be used' do
      opts = {
        'receipt_event' => 'hlr_received',
        'email_identifier' => { 'id_value' => 'fake_email@email.com' }, # missing id_type
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(2021, 11, 11, 1, 2, 3).iso8601,
        'guid' => '1234556'
      }

      expect(Rails.logger).to receive(:error)
      expect(client).not_to have_received(:send_email)

      job.perform(opts)
    end

    it 'errors if the template id cannot be found' do
      error_prefix = 'AppealReceived: could not find template id for'

      opts = {
        'receipt_event' => 'hlr_received',
        'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
        'guid' => '1234556',
        'claimant_email' => '',
        'claimant_first_name' => ''
      }

      expect(Rails.logger).to receive(:error).with "#{error_prefix} higher_level_review_received"
      expect(client).not_to have_received(:send_email)

      job.perform(opts)

      opts['claimant_email'] = 'fake_claimant_email@email.com'
      opts['claimant_first_name'] = 'Betty'

      expect(Rails.logger).to receive(:error).with "#{error_prefix} higher_level_review_received_claimant"
      expect(client).not_to have_received(:send_email)

      job.perform(opts)
    end

    it 'errors if claimant info is missing email' do
      opts = {
        'receipt_event' => 'hlr_received',
        'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
        'guid' => '1234556',
        'claimant_email' => '   ', # Blank email
        'claimant_first_name' => 'Betty'
      }

      guid = opts['guid']
      error_message = "No lookup value present for AppealsApi::AppealReceived notification HLR - GUID: #{guid}"

      expect(Rails.logger).to receive(:error).with error_message
      expect(client).not_to have_received(:send_email)

      job.perform(opts)
    end

    it 'sends an email' do
      with_settings(Settings.vanotify.services.lighthouse.template_id,
                    higher_level_review_received: 'veteran_template',
                    higher_level_review_received_claimant: 'claimant_template') do
        opts = {
          'receipt_event' => 'hlr_received',
          'email_identifier' => { 'id_value' => 'fake_email@email.com', 'id_type' => 'email' },
          'first_name' => 'first name',
          'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
          'guid' => '1234556',
          'claimant_email' => '',
          'claimant_first_name' => ''
        }

        job.perform(opts)

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
        opts = {
          'receipt_event' => 'hlr_received',
          'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
          'first_name' => 'first name',
          'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
          'guid' => '1234556'
        }

        job.perform(opts)

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
        opts = {
          'receipt_event' => 'hlr_received',
          'email_identifier' => { 'id_type' => 'email', 'id_value' => 'fake_email@email.com' }, # key order changed
          'first_name' => 'veteran first name',
          'date_submitted' => DateTime.new(2021, 1, 2, 3, 4, 5).iso8601,
          'guid' => '1234556',
          'claimant_email' => 'fake_claimant_email@email.com',
          'claimant_first_name' => 'Betty'
        }

        job.perform(opts)

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
  end

  it 'uses icn if email isn\'t present' do
    with_settings(
      Settings.vanotify.services.lighthouse.template_id,
      higher_level_review_received: 'fake_template_id'
    ) do
      opts = {
        'receipt_event' => 'hlr_received',
        'email_identifier' => { 'id_value' => '1233445353', 'id_type' => 'ICN' },
        'first_name' => 'first name',
        'date_submitted' => DateTime.new(1900, 1, 2, 3, 4, 5).iso8601,
        'guid' => '1234556'
      }

      job.perform(opts)

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
