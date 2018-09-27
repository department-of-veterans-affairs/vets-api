# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::WorkflowReport do
  let(:user) { build(:user, :loa3) }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:async_transaction) { FactoryBot.create(:va526ez_submit_transaction) }
  let(:steps) { EVSS::DisabilityCompensationForm::WorkflowSteps.new }
  let(:report) { described_class.new(saved_claim.id) }

  before(:each) do
    saved_claim.async_transaction = AsyncTransaction::EVSS::VA526ezSubmitTransaction.start(
      user.uuid, user.edipi, SecureRandom.uuid
    )
  end

  describe '#form_526_success?' do
    subject { report.form_526_success? }

    context 'when it is not complete' do
      it { is_expected.to be_falsey }
    end

    context 'when it is complete' do
      before { saved_claim.async_transaction.update_attribute(:transaction_status, 'received') }
      it { is_expected.to be_truthy }
    end
  end

  describe '#uploads_success?' do
    subject { report.uploads_success? }

    before(:each) { steps.set_has_uploads(saved_claim.id) }

    context 'when it is not complete' do
      it { is_expected.to be_falsey }
    end

    context 'when it is complete' do
      before { steps.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#form_4142_success?' do
    subject { report.form_4142_success? }

    before(:each) { steps.set_has_form_4142(saved_claim.id) }

    context 'when it is not complete' do
      it { is_expected.to be_falsey }
    end

    context 'when it is complete' do
      before { steps.form_4142_success_handler(saved_claim.id) }
      it { is_expected.to be_truthy }
    end
  end

  describe '#worflow_success?' do
    subject { report.workflow_success? }

    context 'without any ancillary items' do
      context 'when it is not complete' do
        it { is_expected.to be_falsey }
      end

      context 'when it is complete' do
        before(:each) { saved_claim.async_transaction.update_attribute(:transaction_status, 'received') }
        it { is_expected.to be_truthy }

        context 'when it includes uploads' do
          before(:each) { steps.set_has_uploads(saved_claim.id) }

          context 'and they have not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and they have completed' do
            before { steps.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id) }
            it { is_expected.to be_truthy }
          end
        end

        context 'when it only includes form 4142' do
          before(:each) { steps.set_has_form_4142(saved_claim.id) }

          context 'and it has not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and it has completed' do
            before { steps.form_4142_success_handler(saved_claim.id) }
            it { is_expected.to be_truthy }
          end
        end

        context 'when it includes uploads and form 4142' do
          before(:each) do
            steps.set_has_uploads(saved_claim.id)
            steps.set_has_form_4142(saved_claim.id)
          end

          context 'and neither have not completed' do
            it { is_expected.to be_falsey }
          end

          context 'and only uploads have completed' do
            before { steps.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id) }
            it { is_expected.to be_falsey }
          end

          context 'and only form 4142 has completed' do
            before { steps.form_4142_success_handler(saved_claim.id) }
            it { is_expected.to be_falsey }
          end

          context 'and both have completed' do
            before do
              steps.uploads_success_handler(nil, 'saved_claim_id' => saved_claim.id)
              steps.form_4142_success_handler(saved_claim.id)
            end
            it { is_expected.to be_truthy }
          end
        end
      end
    end
  end
end
