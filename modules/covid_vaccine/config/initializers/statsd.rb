# frozen_string_literal: true

StatsD.logger = Logger.new 'log/statsd.log' if Rails.env.development?

Rails.application.reloader.to_prepare do
  CovidVaccine::SubmissionJob.extend StatsD::Instrument
  CovidVaccine::SubmissionJob.statsd_count_success :perform,
                                                   'covid_vaccine.submission_job'

  CovidVaccine::V0::RegistrationService.extend StatsD::Instrument
  CovidVaccine::V0::RegistrationService.statsd_measure :facility_attributes,
                                                       'covid_vaccine.facility_query.measure'
  CovidVaccine::V0::RegistrationService.statsd_count_success :facility_attributes,
                                                             'covid_vaccine.facility_query', &:present?
  CovidVaccine::V0::RegistrationService.statsd_measure :attributes_from_mpi,
                                                       'covid_vaccine.mpi_query.measure'
  CovidVaccine::V0::RegistrationService.statsd_measure :submit,
                                                       'covid_vaccine.vetext_submit.measure'
  CovidVaccine::V0::RegistrationService.statsd_count_success :attributes_from_mpi,
                                                             'covid_vaccine.mpi_query', &:present?
  CovidVaccine::V0::RegistrationService.statsd_count_success :submit,
                                                             'covid_vaccine.vetext_submit'
end
