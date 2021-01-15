# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::Process10203Submissions, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:evss_user) { create(:evss_user) }
  let(:evss_user2) { create(:evss_user, uuid: '87ebe3da-36a3-4c92-9a73-61e9d700f6ea') }

  let!(:application_10203) do
    claim = create(:va10203)
    claim.create_stem_automated_decision(evss_user)
    claim
  end

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
      application_10203.education_benefits_claim.saved_claim.form = {}.to_json
      application_10203.education_benefits_claim.saved_claim.save!(validate: false)

      expect(subject).to receive(:log_exception_to_sentry).with(instance_of(EducationForm::FormattingError))

      subject.send(:format_application, EducationBenefitsClaim.find(application_10203.education_benefits_claim.id))
    end
  end

  describe '#group_user_uuid' do
    it 'takes a list of records into groups by user_uuid' do
      application_user2 = create(:va10203)
      application_user2.create_stem_automated_decision(evss_user2)

      submissions = [application_10203, application_user2]
      users = [evss_user, evss_user2]

      output = subject.send(:group_user_uuid, submissions.map(&:education_benefits_claim))
      expect(output.keys).to eq(users.map(&:uuid))
    end
  end
end
