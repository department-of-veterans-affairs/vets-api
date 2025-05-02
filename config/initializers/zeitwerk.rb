# frozen_string_literal: true

Rails.autoloaders.each do |autoloader|
  autoloader.inflector.inflect(
    # This is needed to satisfy Zeitwerk when the following is added to `config/application.rb`:
    #   config.autoload_lib(ignore: %w[assets tasks])
    # Normally it would make sense to add a new inflection.acronym to inflections.rb,
    # but this has an adverse effect on the Mobile::V0::AppointmentsController
    # because it is expecting the field `start_time_utc` to be converted to `startTimeUtc`
    # (this is enforced by a check against `modules/mobile/docs/openapi.json`). If that is
    # resolved then it would make sense to remove this custom inflection and add
    # inflection.acronym "UTC" to `config/initializers/inflections.rb`
    # See more:
    #  https://guides.rubyonrails.org/autoloading_and_reloading_constants.html#customizing-inflections
    "utc_time" => "UTCTime",
  )
end
