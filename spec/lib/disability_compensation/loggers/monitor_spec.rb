# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/loggers/monitor'

RSpec.describe DisabilityCompensation::Loggers::Monitor do
  let(:monitor) { described_class.new }

  # Simple test to ensure monitor successfully implements abstract methods in lib/logging/base_monitor.rb
  describe('#submit_event') do
    it 'logs with the appropriate Disability Compensation key prefixes and metadata' do
      payload = {
        confirmation_number: nil,
        user_account_uuid: '1234',
        claim_id: '1234',
        form_id: described_class::FORM_ID,
        tags: [],
        additional_context_key: 'value'
      }

      expect(monitor).to receive(:track_request).with(
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        call_location: anything,
        **payload
      )

      monitor.send(
        :submit_event,
        :error,
        'Example message',
        described_class::CLAIM_STATS_KEY,
        payload
      )
    end
  end

  describe('#track_saved_claim_save_error') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:in_progress_form) { create(:in_progress_form) }
    let(:mock_form_error) { 'Mock form validation error' }

    let(:claim_with_save_error) do
      claim = SavedClaim::DisabilityCompensation::Form526AllClaim.new
      errors = ActiveModel::Errors.new(claim)
      errors.add(:form, mock_form_error)
      allow(claim).to receive_messages(errors:)
      claim
    end

    it 'logs the error metadata' do
      expect(monitor).to receive(:submit_event).with(
        :error,
        "#{described_class} Form526 SavedClaim save error",
        "#{described_class::CLAIM_STATS_KEY}.failure",
        form_id: described_class::FORM_ID,
        in_progress_form_id: in_progress_form.id,
        errors: [{ form: mock_form_error }].to_s,
        user_account_uuid: user.uuid
      )

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors.errors,
        in_progress_form.id,
        user.uuid
      )
    end

    # NOTE: in_progress_form_id, user_account_uuid, and errors keys are whitelisted payload keys
    # for monitors inheriting from Logging::BaseMonitor; ensures this information will not be filtered out when it is
    # written to the Rails logger; see config/initializers/filter_parameter_logging.rb
    it 'does not filter out error details when writing to the Rails logger' do
      expect(Rails.logger).to receive(:error) do |_, payload|
        expect(payload[:context][:user_account_uuid]).to eq(user.uuid)
        expect(payload[:context][:errors]).to eq([{ form: mock_form_error }].to_s)
        expect(payload[:context][:in_progress_form_id]).to eq(in_progress_form.id)
      end

      monitor.track_saved_claim_save_error(
        claim_with_save_error.errors,
        in_progress_form.id,
        user.uuid
      )
    end
  end

  describe('#track_saved_claim_save_success') do
    let(:user) { build(:disabilities_compensation_user, icn: '123498767V234859') }
    let(:claim) { build(:fake_saved_claim, form_id: described_class::FORM_ID, guid: '1234') }

    it 'logs the success' do
      expect(monitor).to receive(:submit_event).with(
        :info,
        "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}",
        "#{described_class::CLAIM_STATS_KEY}.success",
        claim:,
        user_account_uuid: user.uuid,
        form_id: described_class::FORM_ID
      )

      monitor.track_saved_claim_save_success(
        claim,
        user.uuid
      )
    end
  end

  describe('#track_toxic_exposure_purge') do
    let(:user_uuid) { '123e4567-e89b-12d3-a456-426614174000' }
    let(:in_progress_form) do
      create(:in_progress_form, form_id: '21-526EZ', form_data: {
               'form526' => {
                 'toxicExposure' => {
                   'conditions' => { 'asthma' => true },
                   'gulfWar1990' => { 'iraq' => true }
                 }
               }
             })
    end
    let(:saved_claim) { build(:fake_saved_claim, form_id: described_class::FORM_ID, guid: '1234') }
    let(:submission) { instance_double(Form526Submission, id: 67_890) }

    context 'when toxic exposure data changed' do
      before do
        allow(saved_claim).to receive(:form).and_return({
          'form526' => {
            'toxicExposure' => {
              'conditions' => { 'asthma' => true }
            }
          }
        }.to_json)
      end

      it 'logs toxic exposure purge detection' do
        expect(monitor).to receive(:submit_event).with(
          :info,
          "Form526Submission=#{submission.id} ToxicExposurePurge=detected",
          "#{described_class::CLAIM_STATS_KEY}.toxic_exposure_purge",
          hash_including(
            user_uuid:,
            in_progress_form_id: in_progress_form.id,
            saved_claim_id: saved_claim.id,
            form526_submission_id: submission.id,
            confirmation_number: saved_claim.confirmation_number,
            had_toxic_exposure_in_sip: true,
            has_toxic_exposure_in_submission: true,
            completely_removed: false
          )
        )

        monitor.track_toxic_exposure_purge(
          in_progress_form:,
          submitted_claim: saved_claim,
          submission:,
          user_uuid:
        )
      end
    end

    context 'when toxic exposure data unchanged' do
      before do
        allow(saved_claim).to receive(:form).and_return({
          'form526' => {
            'toxicExposure' => {
              'conditions' => { 'asthma' => true },
              'gulfWar1990' => { 'iraq' => true }
            }
          }
        }.to_json)
      end

      it 'does not log' do
        expect(monitor).not_to receive(:submit_event)

        monitor.track_toxic_exposure_purge(
          in_progress_form:,
          submitted_claim: saved_claim,
          submission:,
          user_uuid:
        )
      end
    end
  end
end
