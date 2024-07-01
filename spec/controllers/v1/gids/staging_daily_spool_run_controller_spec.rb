# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V1::GIDS::StagingDailySpoolRunController, type: :controller do
  include SchemaMatchers

  describe '#index' do
    before do
      allow(Settings).to receive(:vsp_environment).and_return('test')
      allow(EducationForm::CreateDailySpoolFiles).to receive(:new).and_return(spool_files_double)
    end

    let(:spool_files_double) { EducationForm::CreateDailySpoolFiles.new }

    context 'when the environment is not production' do
      it 'deletes all records for today' do
        create(:spool_file_event, :successful)
        VCR.use_cassette('gi_client/gets_run_daily_spool') do
          get(:index)
        end

        expect(SpoolFileEvent.count).to eq(0)
      end

      it 'calls EducationForm::CreateDailySpoolFiles#new' do
        expect(spool_files_double).to receive(:perform)
        subject.index
      end
    end

    context 'when the environment is production' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'does not delete any records' do
        create(:spool_file_event, :successful)
        VCR.use_cassette('gi_client/gets_run_daily_spool') do
          get(:index)
        end

        expect(SpoolFileEvent.count).to eq(1)
      end

      it 'does not call EducationForm::CreateDailySpoolFiles#perform' do
        expect(spool_files_double).not_to receive(:perform)
        subject.index
      end
    end
  end
end
