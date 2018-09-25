# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::Reporting do
  let(:user) { build(:user, :loa3) }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:async_transaction) { FactoryBot.create(:va526ez_submit_transaction) }

  before(:each) do
    saved_claim.async_transaction = AsyncTransaction::EVSS::VA526ezSubmitTransaction.start(
      user.uuid, user.edipi, SecureRandom.uuid
    )
  end

  describe '#worflow_complete?' do
    context 'without any ancillary items' do
      context 'when it is not complete' do
        it 'returns false' do
          expect(subject.workflow_complete?(saved_claim.id)).to be_falsey
        end
      end
    end
  end

  describe '#uploads_marker' do
    it 'marks the submission as having uploads' do
      subject.set_has_uploads(saved_claim.id)
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.has_uploads?).to be_truthy
    end
  end

  describe '#uploads_success_handler' do
    it 'reports that the submission uploads have succeeded' do
      subject.uploads_success_handler(nil, { 'saved_claim_id' => saved_claim.id })
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.uploads_success?).to be_truthy
    end
  end

  describe '#form_4142_marker' do
    it 'marks the submission as having a 4142 form' do
      subject.set_has_form_4142(saved_claim.id)
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.has_form_4142?).to be_truthy
    end
  end

  describe '#form_4142_success_handler' do
    it 'reports that the submission 4142 form has succeeded' do
      subject.form_4142_success_handler(saved_claim.id)
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.form_4142_success?).to be_truthy
    end
  end
end
