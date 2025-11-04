# frozen_string_literal: true

# Dictionary of minimum app versions required for specific features
# Used to determine if a user has access to certain services based on their app version
Mobile::APP_VERSION_REQUIREMENTS = {
  allergiesOracleHealth: '2.63.0',
  medicationsOracleHealth: '2.63.0',
  labsOracleHealth: '2.59.0'
}.freeze
