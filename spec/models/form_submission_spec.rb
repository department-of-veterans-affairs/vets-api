# frozen_string_literal: true

require 'rails_helper'
require 'securerandom'

RSpec.describe FormSubmission, type: :model do
  let(:user_account) { create(:user_account) }

  describe 'associations' do
    it { is_expected.to belong_to(:saved_claim).optional }
    it { is_expected.to belong_to(:user_account).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:form_type) }
  end

  describe 'user form submission statuses' do
    before do
      @fsa = create(:form_submission, form_type: 'FORM-A', benefits_intake_uuid: SecureRandom.uuid, user_account:)
      @fsb = create(:form_submission, form_type: 'FORM-B', benefits_intake_uuid: SecureRandom.uuid, user_account:)
      @fsc = create(:form_submission, form_type: 'FORM-C', benefits_intake_uuid: SecureRandom.uuid, user_account:)

      @fsa1 = create(
        :form_submission_attempt,
        benefits_intake_uuid: SecureRandom.uuid,
        form_submission: @fsa,
        created_at: 3.days.ago
      )
      @fsa2 = create(
        :form_submission_attempt,
        benefits_intake_uuid: SecureRandom.uuid,
        form_submission: @fsa,
        created_at: 2.days.ago
      )
      @fsa3 = create(
        :form_submission_attempt,
        benefits_intake_uuid: SecureRandom.uuid,
        form_submission: @fsa,
        created_at: 1.day.ago
      )
      @fsb1 = create(
        :form_submission_attempt,
        benefits_intake_uuid: SecureRandom.uuid,
        form_submission: @fsb,
        created_at: 1.day.ago
      )
    end

    context 'when form submission has no attempts' do
      it 'returns benefits_intake_id from the form submission' do
        result = FormSubmission.with_latest_intake(user_account).with_form_types(['FORM-C']).first

        expect(result.benefits_intake_uuid).to eq(@fsc.benefits_intake_uuid)
      end
    end

    context 'when form submission has multple attempts' do
      it 'returns the benefits_intake_id from the latest form submission attempt' do
        result = FormSubmission.with_latest_intake(user_account).with_form_types(['FORM-A']).first

        expect(result.benefits_intake_uuid).to eq(@fsa3.benefits_intake_uuid)
      end
    end

    context 'when form submission has a single attempt with uuid' do
      it 'returns the benefits_intake_id from the only form submission attempt' do
        result = FormSubmission.with_latest_intake(user_account).with_form_types(['FORM-B']).first

        expect(result.benefits_intake_uuid).to eq(@fsb1.benefits_intake_uuid)
      end
    end

    context 'when form submission has a single attempt with no uuid' do
      it 'returns the benefits_intake_id from the only form submission' do
        @fsb1.update!(benefits_intake_uuid: nil)
        result = FormSubmission.with_latest_intake(user_account).with_form_types(['FORM-B']).first

        expect(result.benefits_intake_uuid).to eq(@fsb.benefits_intake_uuid)
      end
    end

    context 'when a list of forms is provided' do
      it 'returns only the records that match the given forms' do
        form_types = %w[FORM-A FORM-B]
        results = FormSubmission.with_latest_intake(user_account).with_form_types(form_types).to_a

        expect(results.count).to eq(2)
        results.each { |form| expect(form_types).to include(form.form_type) }
      end
    end

    context 'when a list of forms is not provided' do
      it 'returns all records' do
        results = FormSubmission.with_form_types(nil).to_a

        expect(results.count).to eq(3)
      end
    end
  end
end
