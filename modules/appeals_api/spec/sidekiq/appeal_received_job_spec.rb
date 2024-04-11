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
              email_address: appeal.veteran.email,
              personalisation: {
                date_submitted: expected_date_submitted,
                first_name: appeal.veteran.first_name
              },
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
                email_address: appeal.claimant.email,
                personalisation: {
                  date_submitted: expected_date_submitted,
                  first_name: appeal.claimant.first_name,
                  veterans_name: appeal.veteran.first_name
                },
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
                recipient_identifier: { id_type: 'ICN', id_value: appeal.veteran_icn },
                personalisation: {
                  date_submitted: expected_date_submitted,
                  first_name: appeal.veteran.first_name
                },
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
              email_address: appeal.veteran.email,
              personalisation: {
                date_submitted: expected_date_submitted,
                first_name: appeal.veteran.first_name
              },
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
                email_address: appeal.claimant.email,
                personalisation: {
                  date_submitted: expected_date_submitted,
                  first_name: appeal.claimant.first_name,
                  veterans_name: appeal.veteran.first_name
                },
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
              email_address: appeal.veteran.email,
              personalisation: {
                date_submitted: expected_date_submitted,
                first_name: appeal.veteran.first_name
              },
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
                email_address: appeal.claimant.email,
                personalisation: {
                  date_submitted: expected_date_submitted,
                  first_name: appeal.claimant.first_name,
                  veterans_name: appeal.veteran.first_name
                },
                template_id: claimant_sc_template_id
              }
            )
          end
        end
      end
    end

    describe 'errors' do
      let(:expected_log) { nil }

      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        allow(VaNotify::Service).to receive(:new).and_return(vanotify_client)
        expect(Rails.logger).to receive(:error).once.with(expected_log)
        with_settings(*settings_args) { job.perform(appeal_id, appeal_class_str, date_submitted_str) }
      end

      context 'appeal PII not available' do
        let(:expected_log) { /#{appeal.class.name}.*#{appeal_id}/ }
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
        let(:expected_log) { /#{appeal_id}/ }
        let(:appeal_id) { SecureRandom.uuid }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end

      context 'submitted_date_str with incorrect format' do
        let(:expected_log) { /iso8601 format/ }
        let(:date_submitted_str) { 'not-a-date' }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end

      context 'missing settings for VANotify templates' do
        let(:expected_log) { /template.*#{hlr_template_name}/ }
        let(:settings_args) { [Settings.vanotify.services.lighthouse.template_id, {}] }

        it 'does not send email' do
          expect(vanotify_client).not_to receive(:send_email)
        end
      end
    end
  end
end
