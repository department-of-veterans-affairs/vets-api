# frozen_string_literal: true

vetext_endpoints = %w[put_vaccine_registry]

Rails.application.reloader.to_prepare do
  vetext_endpoints.each do |endpoint|
    StatsD.increment("api.vetext.#{endpoint}.total", 0)
    StatsD.increment("api.vetext.#{endpoint}.fail", 0)
  end

  CovidVaccine::SubmissionJob.extend StatsD::Instrument
  CovidVaccine::SubmissionJob.statsd_count_success :perform,
                                                   'covid_vaccine.submission_job'

  StatsD.increment('covid_vaccine.submission_job.success', 0)
  StatsD.increment('covid_vaccine.submission_job.failure', 0)

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

StatsD.increment('covid_vaccine.facility_query.success', 0)
StatsD.increment('covid_vaccine.facility_query.failure', 0)
StatsD.increment('covid_vaccine.mpi_query.success', 0)
StatsD.increment('covid_vaccine.mpi_query.failure', 0)
StatsD.increment('covid_vaccine.vetext_submit.success', 0)
StatsD.increment('covid_vaccine.vetext_submit.failure', 0)
StatsD.increment('worker.covid_vaccine_registration_email.error', 0)
StatsD.increment('worker.covid_vaccine_registration_email.success', 0)
StatsD.increment('worker.covid_vaccine_expanded_registration_email.error', 0)
StatsD.increment('worker.covid_vaccine_expanded_registration_email.success', 0)
StatsD.increment('worker.covid_vaccine_enrollment_upload.error', 0)
StatsD.increment('worker.covid_vaccine_schedule_batch.success', 0)
StatsD.increment('worker.covid_vaccine_enrollment_upload.error', 0)
StatsD.increment('worker.covid_vaccine_enrollment_upload.success', 0)
