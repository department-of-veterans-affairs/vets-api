module CovidVaccineTrial
  class Engine < ::Rails::Engine
    isolate_namespace CovidVaccineTrial
    config.generators.api_only = true
  end
end
