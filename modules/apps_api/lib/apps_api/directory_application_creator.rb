# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
module AppsApi
  class DirectoryApplicationCreator
    def call
      DirectoryApplication.find_or_initialize_by(name: 'Apple Health').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/AppleHealth+Logo+1024x1024.png'
        app.app_type = 'Third-Party-OAuth'
        app.service_categories = ['Health']
        app.platforms = ['iOS']
        app.app_url = 'https://www.apple.com/ios/health/'
        app.description =
          'With the Apple Health app, you can see all your health records — such as '\
          'medications, immunizations, lab results, and more — in one place. The Health app '\
          'continually updates these records giving you access to a single, integrated snapshot '\
          'of your health profile whenever you want, quickly and privately. All Health Records data '\
          'is encrypted and protected with the user’s iPhone passcode, Touch ID or Face ID.'
        app.privacy_url = 'https://www.apple.com/legal/privacy/'
        app.tos_url = 'https://www.apple.com/legal/sla/'
        app.save
      end
      DirectoryApplication.find_or_initialize_by(name: 'iBlueButton').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/iBlueButton+Logo+1024+x+1024.png'
        app.app_type = 'Third-Party-OAuth'
        app.service_categories = ['Health']
        app.platforms = %w[iOS Android]
        app.app_url = 'https://ibluebutton.com'
        app.description =
          'iBlueButton places your VA medical information securely onto your phone or '\
          'tablet, assembled into an interactive health record, with personalized safety '\
          'warnings for severe drug interactions, opioids, chronic condition care guidelines, '\
          'and information regarding and risk for severe COVID-19 infection. iBlueButton '\
          'has been a VA Blue Button health partner since 2012 and is available to Veterans free of charge.'
        app.privacy_url = 'https://ice.ibluebutton.com/docs/ibb/privacy_policy.html'
        app.tos_url = 'https://ice.ibluebutton.com/docs/ibb/eula.html'
        app.save
      end
      DirectoryApplication.find_or_initialize_by(name: 'Coral Health').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/CoralHealth+1024x1024.png'
        app.app_type = 'Third-Party-OAuth'
        app.service_categories = ['Health']
        app.platforms = %w[iOS Android]
        app.app_url = 'https://mycoralhealth.com'
        app.description =
          'Coral Health is a free personal healthcare management app that is used to track medications,'\
          ' get medication reminders, consolidate official medical records,'\
          ' and monitor health trends and issues over time.'
        app.privacy_url = 'https://mycoralhealth.com/privacy-policy'
        app.tos_url = 'https://mycoralhealth.com/terms-of-service'
        app.save
      end

      DirectoryApplication.find_or_initialize_by(name: 'MyLinks').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/MyLinks+Logo+1024x1024.png'
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
        app.save
      end
      DirectoryApplication.find_or_initialize_by(name: 'Clinical Trial Selector').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/CTS+1024x1024.png'
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
        app.save
      end
      DirectoryApplication.find_or_initialize_by(name: 'OneRecord').tap do |app|
        app.logo_url = 'https://dvp-oauth-application-directory-logos.s3-us-gov-west-1.amazonaws.com/One+Record1024x1024.png'
        app.app_type = 'Third-Party-OAuth'
        app.service_categories = ['Health']
        app.platforms = %w[Web iOS Android]
        app.app_url = 'https://onerecord.com'
        app.description =
          "Your Health, Your Life, Your OneRecord.\n\n"\
          'OneRecord is an app that enables you to build a consolidated medical record of your full health history. '\
          'Whether you have medical records from your time in active duty, your treatment at VA facilities, '\
          'or from doctors and hospitals outside of the military system, '\
          "secure your medical records in one place — your OneRecord.\n\n"\
          'Available on IOS, Android, and on the web at www.onerecord.com'
        app.privacy_url = 'https://onerecord.com/privacy'
        app.tos_url = 'https://onerecord.com/terms'
        app.save
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
