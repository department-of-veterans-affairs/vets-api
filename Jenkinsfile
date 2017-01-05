def env_vars = [
    'RAILS_ENV=test',
    'HOSTNAME=www.example.com',
    'SAML_CERTIFICATE_FILE=spec/support/certificates/ruby-saml.crt',
    'SAML_KEY_FILE=spec/support/certificates/ruby-saml.key',
    'SAML_RELAY=http://localhost:3001/auth/login/callback',
    'SAML_LOGOUT_RELAY=http://localhost:3001/logout',
    'REDIS_HOST=localhost',
    'REDIS_PORT=6379',
    'MHV_HOST=https://mock-prescriptions-api.herokuapp.com',
    'MHV_APP_TOKEN=fake-app-token',
    'DB_ENCRYPTION_KEY=f01ff8ebd1a2b053ad697ae1f0d86adb48ebb708021e4c76c3807d37f6b4e389d5aa45ea171f2f5074222784c1ee2bb8272390d1b9517a7a6987c22733ef00b2',
    'MHV_SM_HOST=https://test.vets.gov',
    'MHV_SM_APP_TOKEN=fake-app-token',
    'EVSS_BASE_URL=https://test.vets.gov',
    'EVSS_SAMPLE_CLAIMANT_USER={"uuid": "1234", "first_name": "Jane", "last_name":"Doe", "edipi": "1105051936", "participant_id": "123456789"}',
    'MVI_URL=http://www.example.com/',
    'MVI_OPEN_TIMEOUT=2',
    'MVI_TIMEOUT=10',
    'MVI_CLIENT_CERT_PATH=/fake/client/cert/path',
    'MVI_CLIENT_KEY_PATH=/fake/client/key/path',
    'MVI_PROCESSING_CODE=T',
    'EVSS_S3_UPLOADS=false',
    'VHA_MAPSERVER_URL=https://services3.arcgis.com/aqgBd3l68G8hEFFE/ArcGIS/rest/services/VHA_Facilities/FeatureServer/0',
    'NCA_MAPSERVER_URL=https://services3.arcgis.com/aqgBd3l68G8hEFFE/ArcGIS/rest/services/NCA_Facilities/FeatureServer/0',
    'VBA_MAPSERVER_URL=https://services3.arcgis.com/aqgBd3l68G8hEFFE/ArcGIS/rest/services/VBA_Facilities/FeatureServer/0',
    'MOCK_MVI_SERVICE=false',
    'GOV_DELIVERY_SERVER=stage-tms.govdelivery.com',
    'ES_URL=https://test.vets.gov',
    'ES_CLIENT_CERT_PATH=/fake/client/cert/path',
    'ES_CLIENT_KEY_PATH=/fake/client/key/path'
]

pipeline {
  agent label:'vets-api-linting'
  stages {
    stage('Checkout Code') {
      steps {
        checkout scm
      }
    }

    stage('Run tests') {
      steps {
        sh 'bash --login -c "bundle install --path vendor/bundle --without development"'
        withEnv(env_vars) {
          sh 'bash --login -c "bundle exec rake db:create db:schema:load ci"'
        }
      }
    }
  }
}
