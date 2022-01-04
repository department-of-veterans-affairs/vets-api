# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Process10203Submissions, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:evss_user) { create(:evss_user) }
  let(:evss_user2) { create(:evss_user, uuid: '87ebe3da-36a3-4c92-9a73-61e9d700f6ea') }
  let(:no_edipi_evss_user) { create(:unauthorized_evss_user) }
  let(:evss_response_with_poa) { OpenStruct.new(body: get_fixture('json/evss_with_poa')) }
  let!(:account) { create(:account, uuid: evss_user.account_uuid) }

  context 'scheduling' do
    before do
      allow(Rails.env).to receive('development?').and_return(true)
    end

    context 'job only runs between 6-18 every 6 hours', run_at: '2017-01-01 00:00:00 EDT' do
      let(:scheduler) { Rufus::Scheduler.new }
      let(:possible_runs) do
        ['2017-01-01 06:00:00 -0500',
         '2017-01-01 12:00:00 -0500',
         '2017-01-01 18:00:00 -0500']
      end

      before do
        yaml = YAML.load_file(Rails.root.join('config', 'sidekiq_scheduler.yml'))
        cron = yaml['EducationForm::Process10203Submissions']['cron']
        scheduler.schedule_cron(cron) {} # schedule_cron requires a block
      end

      it 'is only triggered by sidekiq-scheduler every 6 hours between 6-18' do
        upcoming_runs = scheduler.timeline(Time.zone.now, 1.day.from_now).map(&:first)
        expected_runs = possible_runs.map { |d| EtOrbi.parse(d.to_s) }
        expect(upcoming_runs.map(&:seconds)).to eq(expected_runs.map(&:seconds))
      end
    end
  end

  describe '#group_user_uuid' do
    before do
      expect(FeatureFlipper).to receive(:send_email?).twice.and_return(false)
    end

    it 'takes a list of records into groups by user_uuid' do
      application_10203 = create(:va10203)
      application_10203.after_submit(evss_user)
      application_user2 = create(:va10203)
      application_user2.after_submit(evss_user2)

      submissions = [application_10203, application_user2]
      users = [evss_user, evss_user2]

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
          allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                                  .and_return(evss_response_with_poa.body)
        end

        it 'changes from init to processed with good answers' do
          application_10203 = create(:va10203)
          application_10203.after_submit(evss_user)

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
            application_10203.after_submit(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)

            application_10203_2 = create(:va10203)
            application_10203_2.after_submit(evss_user)

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
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                    .and_return(gi_bill_status)
        end

        it 'is denied' do
          application_10203 = create(:va10203, :automated_bad_answers)
          application_10203.after_submit(evss_user)
          # allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
          #                                                      .and_return(evss_response_with_poa.body)

          # expect do
          #   subject.perform
          # end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
          #            .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)
        end
      end

      it 'evss user with no entitlement is processed' do
        application_10203 = create(:va10203)
        application_10203.after_submit(evss_user)
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_with_poa.body)

        expect do
          subject.perform
        end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                   .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
      end

      it 'skips POA check when :stem_automated_decision flag is on' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, any_args).and_return(true).at_least(:once)
        application_10203 = create(:va10203)
        application_10203.after_submit(evss_user)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(nil)
      end

      it 'skips POA check for user without an EDIPI' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, any_args).and_return(false).at_least(:once)
        application_10203 = create(:va10203)
        application_10203.after_submit(no_edipi_evss_user)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(nil)
      end

      it 'sets claim poa for evss user without poa' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, any_args).and_return(false).at_least(:once)
        application_10203 = create(:va10203)
        application_10203.after_submit(evss_user)
        evss_response_without_poa = OpenStruct.new({ 'userPoaInfoAvailable' => false })
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_without_poa)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(false)
      end

      it 'sets claim poa for evss user with poa' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, any_args).and_return(false).at_least(:once)
        application_10203 = create(:va10203)
        application_10203.after_submit(evss_user)
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_with_poa.body)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(true)
      end

      it 'sets claim poa for claim with decision poa flag' do
        application_10203 = create(:education_benefits_claim_10203,
                                   processed_at: Time.zone.now.beginning_of_day,
                                   education_stem_automated_decision: build(:education_stem_automated_decision,
                                                                            :with_poa, :denied))

        subject.perform
        application_10203.reload
        expect(application_10203.education_stem_automated_decision.poa).to eq(true)
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
