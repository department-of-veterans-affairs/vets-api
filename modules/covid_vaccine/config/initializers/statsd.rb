# frozen_string_literal: true

vetext_endpoints = %w[put_vaccine_registry]

vetext_endpoints.each do |endpoint|
  StatsD.increment("api.vetext.#{endpoint}.total", 0)
  StatsD.increment("api.vetext.#{endpoint}.fail", 0)
end

CovidVaccine::V0::RegistrationService.extend StatsD::Instrument
CovidVaccine::V0::RegistrationService.statsd_measure :attributes_from_mpi,
                                                     'covid_vaccine.mpi_query.measure'
CovidVaccine::V0::RegistrationService.statsd_measure :submit,
                                                     'covid_vaccine.vetext_submit.measure'
CovidVaccine::V0::RegistrationService.statsd_count_success :attributes_from_mpi,
                                                           'covid_vaccine.mpi_query' do |result|
  result.present?
end
CovidVaccine::V0::RegistrationService.statsd_count_success :submit,
                                                           'covid_vaccine.vetext_submit'

StatsD.increment('covid_vaccine.mpi_query.success', 0)
StatsD.increment('covid_vaccine.mpi_query.failure', 0)
StatsD.increment('covid_vaccine.vetext_submit.success', 0)
StatsD.increment('covid_vaccine.vetext_submit.failure', 0)
