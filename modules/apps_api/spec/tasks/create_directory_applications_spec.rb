# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe AppsApi do
  context 'apps_api:create_applications' do
    let(:run_create_application_task) do
      Rake::Task['apps_api:create_applications'].invoke
    end

    it 'runs without error' do
      expect { run_create_application_task }.not_to raise_error
    end

    context 'after invoking task' do
      Rails.application.load_tasks
      Rake::Task['apps_api:create_applications'].invoke

      it 'processed Apple Health' do
        expect(DirectoryApplication.where(name: 'Apple Health')).to exist
      end
      it 'processed iBlueButton' do
        expect(DirectoryApplication.where(name: 'iBlueButton')).to exist
      end
      it 'processed MyLinks' do
        expect(DirectoryApplication.where(name: 'MyLinks')).to exist
      end
      it 'processed Clinical Trial Selector' do
        expect(DirectoryApplication.where(name: 'Clinical Trial Selector')).to exist
      end
      it 'does not process an app without all fields given' do
        expect do
          DirectoryApplication.find_or_create_by!(name: 'Something that doesnt exist')
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end
end
