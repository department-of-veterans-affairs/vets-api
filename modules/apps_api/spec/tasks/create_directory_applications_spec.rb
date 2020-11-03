# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe AppsApi do
  before do
    Rails.application.load_tasks
  end

  let(:run_create_application_task) do
    Rake::Task['apps_api:create_applications'].invoke
  end

  it 'runs without error' do
    expect { run_create_application_task }.not_to raise_error
  end

  it 'processed Apple Health' do
    resp = DirectoryApplication.find_or_create_by!(name: 'Apple Health') do |app|
      app.logo_url = 'https://ok5static.oktacdn.com/fs/bco/4/fs01ca0lwp7cApBuM297'
      app.app_type = 'Third-Party-OAuth'
      app.service_categories = ['Health']
      app.platforms = ['IOS']
      app.app_url = 'https://www.apple.com/ios/health/'
      app.description =
        'With the Apple Health app, you can see all your health records — such as '\
        'medications, immunizations, lab results, and more — in one place. The Health app '\
        'continually updates these records giving you access to a single, integrated snapshot '\
        'of your health profile whenever you want, quickly and privately. All Health Records data '\
        'is encrypted and protected with the user’s iPhone passcode, Touch ID or Face ID.'
      app.privacy_url = 'https://www.apple.com/legal/privacy/'
      app.tos_url = 'https://www.apple.com/legal/sla/'
    end
    expect(resp).to eq(DirectoryApplication.find_by(name: 'Apple Health'))
  end

  it 'processed iBlueButton' do
    resp = DirectoryApplication.find_or_create_by!(name: 'iBlueButton') do |app|
      app.logo_url = 'https://ok5static.oktacdn.com/fs/bco/4/fs0499ofxnUUHtF1i297'
      app.app_type = 'Third-Party-OAuth'
      app.service_categories = ['Health']
      app.platforms = %w[IOS Android]
      app.app_url = 'https://ice.ibluebutton.com'
      app.description =
        'iBlueButton places your VA medical information securely onto your phone or '\
        'tablet, assembled into an interactive health record, with personalized safety '\
        'warnings for severe drug interactions, opioids, chronic condition care guidelines, '\
        'and information regarding and risk for severe COVID-19 infection. iBlueButton '\
        'has been a VA Blue Button health partner since 2012 and is available to Veterans free of charge.'
      app.privacy_url = 'https://ice.ibluebutton.com/docs/ibb/privacy_policy.html'
      app.tos_url = 'https://ice.ibluebutton.com/docs/ibb/eula.html'
    end
    expect(resp).to eq(DirectoryApplication.find_by(name: 'iBlueButton'))
  end
  it 'processed MyLinks' do
    resp = DirectoryApplication.find_or_create_by!(name: 'MyLinks') do |app|
      app.logo_url = 'https://ok5static.oktacdn.com/fs/bco/4/fs0499ofptWwE5ruy297'
      app.app_type = 'Third-Party-OAuth'
      app.service_categories = ['Health']
      app.platforms = ['Web']
      app.app_url = 'https://mylinks.com'
      app.description =
        'MyLinks is a free application that provides Veterans '\
        'with their own secure and complete personal health record fully under their control. '\
        'Veterans can gather, aggregate, and share their health records from their VA and '\
        'non-VA health care providers into one place. They can add other important documents '\
        'and images, connect devices, and keep a journal. MyLinks is accessible from any mobile device.'
      app.privacy_url = 'https://mylinks.com/privacypolicy'
      app.tos_url = 'https://mylinks.com/termsofservice'
    end
    expect(resp).to eq(DirectoryApplication.find_by(name: 'MyLinks'))
  end
  it 'processed Clinical Trial Selector' do
    resp = DirectoryApplication.find_or_create_by!(name: 'Clinical Trial Selector') do |app|
      app.logo_url = 'https://cts.girlscomputingleague.org/static/img/CTS-white-100.png'
      app.app_type = 'Third-Party-OAuth'
      app.service_categories = ['Health']
      app.platforms = ['Web']
      app.app_url = 'https://cts.girlscomputingleague.org/'
      app.description =
        'The Clinical Trials Selector is an app that utilizes the Electronic '\
        'Health Records of service-connected Veterans in order to match Veterans '\
        'to clinical trials. The application takes into account, diagnoses, '\
        'demographics, prescribed medications, patient procedures, and laboratory '\
        'values from the EHR to automatically find eligible trials.'
      app.privacy_url = 'https://cts.girlscomputingleague.org/generalprivacypolicy.html'
      app.tos_url = 'https://cts.girlscomputingleague.org/generaltermsofuse.html'
    end
    expect(resp).to eq(DirectoryApplication.find_by(name: 'Clinical Trial Selector'))
  end

  it 'does not process an app without all fields given' do
    expect do
      DirectoryApplication.find_or_create_by!(name: 'Something that doesnt exist')
    end.to raise_error(ActiveRecord::RecordInvalid)
  end
end
