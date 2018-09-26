# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::Reporting do
  let(:user) { build(:user, :loa3) }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:async_transaction) { FactoryBot.create(:va526ez_submit_transaction) }
  let(:report) { described_class.new(saved_claim.id) }

  before(:each) do
    saved_claim.async_transaction = AsyncTransaction::EVSS::VA526ezSubmitTransaction.start(
      user.uuid, user.edipi, SecureRandom.uuid
    )
  end

  subject { report }

  describe '#uploads_marker' do
    it 'marks the submission as having uploads' do
      subject.set_has_uploads
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.has_uploads?).to be_truthy
    end
  end

  describe '#uploads_success_handler' do
    it 'reports that the submission uploads have succeeded' do
      subject.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id)
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.uploads_success?).to be_truthy
    end
  end

  describe '#form_4142_marker' do
    it 'marks the submission as having a 4142 form' do
      subject.set_has_form_4142
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.has_form_4142?).to be_truthy
    end
  end

  describe '#form_4142_success_handler' do
    it 'reports that the submission 4142 form has succeeded' do
      subject.form_4142_success_handler
      saved_claim.reload
      expect(saved_claim.disability_compensation_submission.form_4142_success?).to be_truthy
    end
  end

  describe '#worflow_complete?' do
    subject { report.workflow_complete? }

    context 'without any ancillary items' do
      context 'when it is not complete' do
        it { is_expected.to be_falsey }
      end

      context 'when it is complete' do
        before(:each) { saved_claim.async_transaction.update_attribute(:transaction_status, 'received') }
        it { is_expected.to be_truthy }

        context 'when it includes uploads' do
          before(:each) { report.set_has_uploads }

          context 'and they have not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and they have completed' do
            before { report.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id) }
            it { is_expected.to be_truthy }
          end
        end

        context 'when it only includes form 4142' do
          before(:each) { report.set_has_form_4142 }

          context 'and it has not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and it has completed' do
            before { report.form_4142_success_handler }
            it { is_expected.to be_truthy }
          end
        end

        context 'when it includes uploads and form 4142' do
          before(:each) do
            report.set_has_uploads
            report.set_has_form_4142
          end

          context 'and neither have not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and only uploads have completed' do
            before { report.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id) }
            it { is_expected.to be_falsey }
          end

          context 'and only form 4142 has completed' do
            before { report.form_4142_success_handler }
            it { is_expected.to be_falsey }
          end

          context 'and both have completed' do
            before do
              report.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id)
              report.form_4142_success_handler
            end
            it { is_expected.to be_truthy }
          end
        end
      end
    end
  end
end
