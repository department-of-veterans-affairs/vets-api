# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Process10203Submissions, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:evss_user) { create(:evss_user) }
  let(:evss_user2) { create(:evss_user, uuid: '87ebe3da-36a3-4c92-9a73-61e9d700f6ea') }
  let(:evss_response_with_poa) { OpenStruct.new(body: get_fixture('json/evss_with_poa')) }

  context 'scheduling' do
    before do
      allow(Rails.env).to receive('development?').and_return(true)
    end

    context 'job only runs between 6-18', run_at: '2017-01-01 00:00:00 EDT' do
      let(:scheduler) { Rufus::Scheduler.new }
      let(:possible_runs) do
        ['2017-01-01 06:00:00 -0500',
         '2017-01-01 07:00:00 -0500',
         '2017-01-01 08:00:00 -0500',
         '2017-01-01 09:00:00 -0500',
         '2017-01-01 10:00:00 -0500',
         '2017-01-01 11:00:00 -0500',
         '2017-01-01 12:00:00 -0500',
         '2017-01-01 13:00:00 -0500',
         '2017-01-01 14:00:00 -0500',
         '2017-01-01 15:00:00 -0500',
         '2017-01-01 16:00:00 -0500',
         '2017-01-01 17:00:00 -0500',
         '2017-01-01 18:00:00 -0500']
      end

      before do
        yaml = YAML.load_file(Rails.root.join('config', 'sidekiq_scheduler.yml'))
        cron = yaml['EducationForm::Process10203Submissions']['cron']
        scheduler.schedule_cron(cron) {} # schedule_cron requires a block
      end

      it 'is only triggered by sidekiq-scheduler between 6-18' do
        upcoming_runs = scheduler.timeline(Time.zone.now, 1.day.from_now).map(&:first)
        expected_runs = possible_runs.map { |d| EtOrbi.parse(d.to_s) }
        expect(upcoming_runs.map(&:seconds)).to eq(expected_runs.map(&:seconds))
      end
    end
  end

  describe '#format_application' do
    it 'logs an error if the record is invalid' do
      application_10203 = create(:va10203)
      application_10203.create_stem_automated_decision(evss_user)
      application_10203.education_benefits_claim.saved_claim.form = {}.to_json
      application_10203.education_benefits_claim.saved_claim.save!(validate: false)

      expect(subject).to receive(:log_exception_to_sentry).with(instance_of(EducationForm::FormattingError))

      subject.send(:format_application, EducationBenefitsClaim.find(application_10203.education_benefits_claim.id))
    end
  end

  describe '#group_user_uuid' do
    it 'takes a list of records into groups by user_uuid' do
      application_10203 = create(:va10203)
      application_10203.create_stem_automated_decision(evss_user)
      application_user2 = create(:va10203)
      application_user2.create_stem_automated_decision(evss_user2)

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
          gi_bill_status = build(:gi_bill_status_response)
          allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                                  .and_return(evss_response_with_poa.body)
          allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                    .and_return(gi_bill_status)
        end

        it 'changes from init to processed with good answers' do
          application_10203 = create(:va10203)
          application_10203.create_stem_automated_decision(evss_user)

          expect do
            subject.perform
          end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                     .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
        end

        it 'changes from init to denied with bad answers' do
          application_10203 = create(:va10203, :automated_bad_answers)
          application_10203.create_stem_automated_decision(evss_user)

          expect do
            subject.perform
          end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                     .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)
        end

        context 'multiple submissions' do
          it 'without any be processed by CreateDailySpoolFiles' do
            application_10203 = create(:va10203, :automated_bad_answers)
            application_10203.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)

            application_10203_2 = create(:va10203, :automated_bad_answers)
            application_10203_2.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.denied.count }.from(1).to(2)
          end

          it 'that have same answers' do
            application_10203 = create(:va10203, :automated_bad_answers)
            application_10203.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)
            application_10203.education_benefits_claim.update(processed_at: Time.zone.now)

            application_10203_2 = create(:va10203, :automated_bad_answers)
            application_10203_2.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
          end

          it 'have different answers' do
            application_10203 = create(:va10203)
            application_10203.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
            application_10203.education_benefits_claim.update(processed_at: Time.zone.now)

            application_10203_2 = create(:va10203, :automated_bad_answers)
            application_10203_2.create_stem_automated_decision(evss_user)

            expect do
              subject.perform
            end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                       .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)
          end
        end
      end

      it 'evss user with more than 180 days is denied' do
        application_10203 = create(:va10203, :automated_bad_answers)
        application_10203.create_stem_automated_decision(evss_user)
        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: { months: 10, days: 12 })
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_with_poa.body)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                  .and_return(gi_bill_status)

        expect do
          subject.perform
        end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                   .and change { EducationStemAutomatedDecision.denied.count }.from(0).to(1)
      end

      it 'evss user with no entitlement is processed' do
        application_10203 = create(:va10203)
        application_10203.create_stem_automated_decision(evss_user)
        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: nil)
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_with_poa.body)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                  .and_return(gi_bill_status)

        expect do
          subject.perform
        end.to change { EducationStemAutomatedDecision.init.count }.from(1).to(0)
                   .and change { EducationStemAutomatedDecision.processed.count }.from(0).to(1)
      end

      it 'sets claim poa for evss user without poa' do
        application_10203 = create(:va10203)
        application_10203.create_stem_automated_decision(evss_user)
        evss_response_without_poa = OpenStruct.new({ 'userPoaInfoAvailable' => false })
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_without_poa)
        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: nil)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                .and_return(gi_bill_status)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(false)
      end

      it 'sets claim poa for evss user with poa' do
        application_10203 = create(:va10203)
        application_10203.create_stem_automated_decision(evss_user)
        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: nil)
        allow_any_instance_of(EVSS::VSOSearch::Service).to receive(:get_current_info)
                                                             .and_return(evss_response_with_poa.body)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
                                                                .and_return(gi_bill_status)

        subject.perform
        application_10203.reload
        expect(application_10203.education_benefits_claim.education_stem_automated_decision.poa).to eq(true)
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
        expect(subject).to receive('log_info').with('No records to process.').once
        expect(subject.perform).to be(true)
      end
    end
  end
end
