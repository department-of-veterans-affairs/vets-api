# frozen_string_literal: true

require 'rails_helper'
require 'fugit'
require 'feature_flipper'

RSpec.describe EducationForm::Process10203Submissions, form: :education_benefits, type: :model do
  subject { described_class.new }

  sidekiq_file = Rails.root.join('lib', 'periodic_jobs.rb')
  lines = File.readlines(sidekiq_file).grep(/EducationForm::Process10203Submissions/i)
  cron = lines.first.gsub("  mgr.register('", '').gsub("', 'EducationForm::Process10203Submissions')\n", '')
  let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
  let(:parsed_schedule) { Fugit.do_parse(cron) }
  let(:user2) { create(:user, uuid: '87ebe3da-36a3-4c92-9a73-61e9d700f6ea') }
  let(:no_edipi_user) { create(:user, :with_terms_of_use_agreement, idme_uuid: SecureRandom.uuid, participant_id: nil) }
  let(:evss_response_with_poa) { OpenStruct.new(body: get_fixture('json/evss_with_poa')) }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  describe 'scheduling' do
    before do
      allow(Rails.env).to receive('development?').and_return(true)
    end

    context 'job only runs between 6-18 every 6 hours', run_at: '2017-01-01 00:00:00 EDT' do
      it 'is only triggered by sidekiq periodic jobs every 6 hours between 6-18' do
        expect(parsed_schedule.original).to eq('0 6-18/6 * * *')
        expect(parsed_schedule.hours).to eq([6, 12, 18])
      end
    end
  end

  describe '#group_user_uuid' do
    before do
      expect(FeatureFlipper).to receive(:send_email?).twice.and_return(false)
    end

    it 'takes a list of records into groups by user_uuid' do
      application_10203 = create(:va10203)
      application_10203.after_submit(user)
      application_user2 = create(:va10203)
      application_user2.after_submit(user2)

      submissions = [application_10203, application_user2]
      users = [user, user2]

      output = subject.send(:group_user_uuid, submissions.map(&:education_benefits_claim))
      expect(output.keys).to eq(users.map(&:uuid))
    end
  end

  describe '#perform' do
    before do
      EducationBenefitsClaim.delete_all
      EducationStemAutomatedDecision.delete_all
    end

    # rubocop:disable Layout/MultilineMethodCallIndentation
    context 'sets automated_decision_state' do
      context 'evss user with less than 180 days of entitlement' do
        before do
          expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
        end

        it 'changes from init to processed with good answers' do
          application_10203 = create(:va10203)
          application_10203.after_submit(user)

          expect do
            subject.perform
          end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                     .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
        end

        context 'multiple submissions' do
          before do
            expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
          end

          it 'without any be processed by CreateDailySpoolFiles' do
            application_10203 = create(:va10203)
            application_10203.after_submit(user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)

            application_10203_2 = create(:va10203)
            application_10203_2.after_submit(user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.processed.count }.from(1).to(2)
          end
        end
      end

      context 'evss user with more than 180 days' do
        before do
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(BenefitsEducation::Service).to receive(:get_gi_bill_status)
                                                                    .and_return(gi_bill_status)
        end
      end

      it 'evss user with no entitlement is processed' do
        application_10203 = create(:va10203)
        application_10203.after_submit(user)

        expect do
          subject.perform
        end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                   .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
      end

      it 'skips POA check for user without an EDIPI' do
        allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email)
        application_10203 = create(:va10203)
        application_10203.after_submit(no_edipi_user)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
      end

      it 'sets POA to nil for new submissions' do
        allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email)
        application_10203 = create(:va10203)
        application_10203.after_submit(user)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
      end

      it 'sets claim poa for claim with decision poa flag' do
        application_10203 = create(:education_benefits_claim_10203,
                                   processed_at: Time.zone.now.beginning_of_day,
                                   education_stem_automated_decision: build(:education_stem_automated_decision,
                                                                            :with_poa, :denied))

        subject.perform
        application_10203.reload
        expect(application_10203.education_stem_automated_decision.poa).to be(true)
      end
    end
    # rubocop:enable Layout/MultilineMethodCallIndentation

    context 'with no records' do
      before do
        EducationBenefitsClaim.delete_all
        EducationStemAutomatedDecision.delete_all
      end

      it 'prints a statement and exits' do
        expect(subject).not_to receive(:process_user_submissions)
        expect(subject).to receive('log_info').with('No records with init status to process.').once
        expect(subject.perform).to be(true)
      end
    end
  end
end
