# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'jobs rake tasks', type: :request do
  before :all do
    Rake.application.rake_require '../rakelib/jobs'
    Rake::Task.define_task(:environment)
  end

  describe 'rake jobs:reset_daily_spool_files_for_today' do
    let :run_rake_task do
      Rake::Task['jobs:reset_daily_spool_files_for_today'].reenable
      Rake.application.invoke_task 'jobs:reset_daily_spool_files_for_today'
    end

    it 'runs without errors in non production environments' do
      allow(Settings).to receive(:vsp_environment).and_return('staging')
      expect { run_rake_task }.not_to raise_error
    end

    it 'raises an exception if the environment is production' do
      allow(Settings).to receive(:vsp_environment).and_return('production')
      expect { run_rake_task }.to raise_error Common::Exceptions::Unauthorized
    end

    it 'deletes spool file event rows created today' do
      rpo = EducationForm::EducationFacility::FACILITY_IDS[:western]
      yday = Time.zone.yesterday
      create(:spool_file_event, filename: "#{rpo}_#{yday.strftime('%m%d%Y_%H%M%S')}_vetsgov.spl", created_at: yday)
      create(:spool_file_event, :successful)
      expect { run_rake_task }.to change(SpoolFileEvent, :count).by(-1)
    end
  end
end
