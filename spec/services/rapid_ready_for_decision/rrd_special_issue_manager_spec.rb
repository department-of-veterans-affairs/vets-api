# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RapidReadyForDecision::RrdSpecialIssueManager do
  let(:form526_submission) { create(:form526_submission, :hypertension_claim_for_increase) }

  def form526_hash(form)
    JSON.parse(form, symbolize_names: true)[:form526][:form526]
  end

  def filter_disabilities(form)
    form[:disabilities].filter do |item|
      RapidReadyForDecision::Constants::DISABILITIES_BY_CODE.include?(item[:diagnosticCode])
    end
  end

  describe '#add_special_issue' do
    subject(:special_issue_manager) { described_class.new(RapidReadyForDecision::ClaimContext.new(form526_submission)) }

    let(:special_issues_list) { ['RRD'] }

    it 'matches the email address after manipulation' do
      address_before = form526_hash(form526_submission.form_json)[:veteran][:emailAddress]
      expect(address_before).to be_present
      subject.add_special_issue

      address_reloaded = form526_hash(form526_submission.reload.form_json)[:veteran][:emailAddress]
      expect(address_reloaded).to match address_before
    end

    it 'adds rrd to the disabilities list' do
      subject.add_special_issue
      filtered_disabilities = filter_disabilities(form526_hash(form526_submission.reload.form_json))
      expect(filtered_disabilities[0][:specialIssues]).to match special_issues_list
    end

    it 'adds rrd to each relevant item in the disabilities list' do
      subject.add_special_issue
      filtered_disabilities = filter_disabilities(form526_hash(form526_submission.reload.form_json))
      expect(filtered_disabilities).to all(include :specialIssues)
      expect(filtered_disabilities.any? { |el| el[:specialIssues].include? special_issues_list.first }).to be true
    end

    context 'for single-issue asthma increase' do
      let(:form526_submission) { create(:form526_submission, :asthma_claim_for_increase) }

      it 'adds rrd to the special issues list' do
        subject.add_special_issue
        filtered_disabilities = filter_disabilities(form526_hash(form526_submission.reload.form_json))
        expect(filtered_disabilities[0][:specialIssues]).to match special_issues_list
      end
    end

    context 'when the fast track worker has been triggered twice for the same submission' do
      before { expect(form526_submission).to receive(:update!).twice.and_call_original }

      it 'adds rrd to the disabilities list only once' do
        subject.add_special_issue
        filtered_disabilities = filter_disabilities(form526_hash(form526_submission.form_json))
        expect(filtered_disabilities[0][:specialIssues]).to match special_issues_list

        subject.add_special_issue
        second_pass_filtered_disabilities = filter_disabilities(form526_hash(form526_submission.form_json))
        expect(second_pass_filtered_disabilities[0][:specialIssues]).to match filtered_disabilities[0][:specialIssues]
      end
    end

    context 'when the update to the Form526Submission record fails' do
      before { allow(form526_submission).to receive(:update!).and_raise(ActiveRecord::RecordInvalid) }

      it 'raises the exception' do
        expect { subject.add_special_issue }.to raise_exception(ActiveRecord::RecordInvalid)
      end
    end

    # TODO: need tests for cases where more than one disability is present.
    # TODO: need tests for cases where hypertension is not one of the disabilities.
    # TODO: maybe need tests for cases where hypertension is present and already has a
    #       non-RRD special issue attached to it.
  end
end
