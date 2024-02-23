# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::AppealReceivedJob, type: :job do
  let(:job) { described_class.new }
  let(:appeal) { create(:higher_level_review_v2) }
  let(:hlr_template_name) { 'higher_level_review_received' }
  let(:nod_template_name) { 'notice_of_disagreement_received' }
  let(:sc_template_name) { 'supplemental_claim_received' }
  let(:hlr_template_id) { SecureRandom.uuid }
  let(:nod_template_id) { SecureRandom.uuid }
  let(:sc_template_id) { SecureRandom.uuid }
  let(:claimant_hlr_template_id) { SecureRandom.uuid }
  let(:claimant_nod_template_id) { SecureRandom.uuid }
  let(:claimant_sc_template_id) { SecureRandom.uuid }
  let(:settings_args) do
    [Settings.vanotify.services.lighthouse.template_id, {
      hlr_template_name.to_sym => hlr_template_id,
      nod_template_name.to_sym => nod_template_id,
      sc_template_name.to_sym => sc_template_id,
      :"#{hlr_template_name}_claimant" => claimant_hlr_template_id,
      :"#{nod_template_name}_claimant" => claimant_nod_template_id,
      :"#{sc_template_name}_claimant" => claimant_sc_template_id
    }]
  end

  describe 'appeal_template_id' do
    it 'finds the ID of the correct VANotify template for the appeal' do
      with_settings(*settings_args) { expect(job.appeal_template_id(appeal)).to equal(hlr_template_id) }
    end
  end

  describe 'perform' do
    let(:vanotify_client) { instance_double(VaNotify::Service) }
    let(:appeal_id) { appeal.id }
    let(:appeal_class_str) { appeal.class.name }
    let(:date_submitted_str) { DateTime.new(2024, 1, 2, 3, 4, 5).iso8601 }

    describe 'successes' do
      let(:expected_tags) { { appeal_type: 'hlr', claimant_type: 'veteran' } }
      let(:expected_date_submitted) { 'January 02, 2024' }

      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_client)
        allow(vanotify_client).to receive(:send_email)
        allow(StatsD).to receive(:increment).with(described_class::STATSD_CLAIMANT_EMAIL_SENT, tags: expected_tags)
        with_settings(*settings_args) { job.perform(appeal_id, appeal_class_str, date_submitted_str) }
      end

      context 'with HLR' do
        it 'sends HLR email to veteran' do
          expect(vanotify_client).to have_received(:send_email).with(
            {
              date_submitted: expected_date_submitted,
              email_address: appeal.veteran.email,
              personalisation: { first_name: appeal.veteran.first_name },
              template_id: hlr_template_id
            }
          )
        end

        context 'with non-veteran claimant' do
          let(:appeal) { create(:extra_higher_level_review_v2) }
          let(:expected_tags) { { appeal_type: 'hlr', claimant_type: 'non-veteran' } }

          it 'sends HLR email to non-veteran claimant' do
            expect(vanotify_client).to have_received(:send_email).with(
              {
                date_submitted: expected_date_submitted,
                email_address: appeal.claimant.email,
                personalisation: { first_name: appeal.claimant.first_name, veterans_name: appeal.veteran.first_name },
                template_id: claimant_hlr_template_id
              }
            )
          end
        end

        context 'if for some hypothetical reason there is no email' do
          let(:form_data) do
            data = fixture_as_json('decision_reviews/v2/valid_200996.json')
            data['data']['attributes']['veteran'].delete('email')
            data
          end
          let(:appeal) { create(:higher_level_review_v2, form_data:) }

          it 'invokes VANotify with ICN instead' do
            expect(vanotify_client).to have_received(:send_email).with(
              {
                date_submitted: expected_date_submitted,
                personalisation: { first_name: appeal.veteran.first_name },
                recipient_identifier: { id_type: 'ICN', id_value: appeal.veteran_icn },
                template_id: hlr_template_id
              }
            )
          end
        end
      end

      context 'with NOD' do
        let(:appeal) { create(:notice_of_disagreement_v2) }
        let(:expected_tags) { { appeal_type: 'nod', claimant_type: 'veteran' } }

        it 'sends NOD email to veteran' do
          expect(vanotify_client).to have_received(:send_email).with(
            {
              date_submitted: expected_date_submitted,
              email_address: appeal.veteran.email,
              personalisation: { first_name: appeal.veteran.first_name },
              template_id: nod_template_id
            }
          )
        end

        context 'with non-veteran claimant' do
          let(:appeal) { create(:extra_notice_of_disagreement_v2) }
          let(:expected_tags) { { appeal_type: 'nod', claimant_type: 'non-veteran' } }

          it 'sends NOD email to non-veteran claimant' do
            expect(vanotify_client).to have_received(:send_email).with(
              {
                date_submitted: expected_date_submitted,
                email_address: appeal.claimant.email,
                personalisation: { first_name: appeal.claimant.first_name, veterans_name: appeal.veteran.first_name },
                template_id: claimant_nod_template_id
              }
            )
          end
        end
      end

      context 'with SC' do
        let(:appeal) { create(:supplemental_claim) }
        let(:expected_tags) { { appeal_type: 'sc', claimant_type: 'veteran' } }

        it 'sends SC email to veteran' do
          expect(vanotify_client).to have_received(:send_email).with(
            {
              date_submitted: expected_date_submitted,
              email_address: appeal.veteran.email,
              personalisation: { first_name: appeal.veteran.first_name },
              template_id: sc_template_id
            }
          )
        end

        context 'with non-veteran claimant' do
          let(:appeal) { create(:extra_supplemental_claim) }
          let(:expected_tags) { { appeal_type: 'sc', claimant_type: 'non-veteran' } }

          it 'sends SC email to non-veteran claimant' do
            expect(vanotify_client).to have_received(:send_email).with(
              {
                date_submitted: expected_date_submitted,
                email_address: appeal.claimant.email,
                personalisation: { first_name: appeal.claimant.first_name, veterans_name: appeal.veteran.first_name },
                template_id: claimant_sc_template_id
              }
            )
          end
        end
      end
    end

    describe 'errors' do
      let(:expected_error) { nil }

      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_client)
        expect do
          with_settings(*settings_args) { job.perform(appeal_id, appeal_class_str, date_submitted_str) }
        end.to raise_error expected_error
      end

      context 'appeal PII not available' do
        let(:expected_error) { /Missing PII for #{appeal.class.name} #{appeal_id}/ }
        let(:appeal) do
          hlr = create(:higher_level_review_v2)
          hlr.update!(form_data: nil, auth_headers: nil)
          hlr
        end

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end

      context 'appeal with given appeal_id not found' do
        let(:appeal_id) { SecureRandom.uuid }
        let(:expected_error) { /find #{appeal_class_str}.*#{appeal_id}/ }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end

      context 'submitted_date_str with incorrect format' do
        let(:expected_error) { /iso8601/ }
        let(:date_submitted_str) { 'not-a-date' }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end

      context 'missing settings for VANotify templates' do
        let(:expected_error) { /template.*#{hlr_template_name}/ }
        let(:settings_args) { [Settings.vanotify.services.lighthouse.template_id, {}] }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end
    end
  end

  describe 'va notify claimant email templates', skip: 'skipped to avoid changing too many lines in a single PR' do
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

  describe 'higher_level_review', skip: 'skipped to avoid changing too many lines in a single PR' do
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

  it 'uses icn if email isn\'t present', skip: 'skipped to avoid changing too many lines in a single PR' do
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
