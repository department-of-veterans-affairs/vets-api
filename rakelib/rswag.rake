# frozen_string_literal: true

namespace :rswag do
  namespace :claims_api do
    desc 'Generate rswag docs for claims_api'
    task run: :environment do
      ENV['PATTERN'] = 'modules/claims_api/spec/requests/**/*_spec.rb'
      ENV['RAILS_MODULE'] = 'claims_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end
  end

  namespace :appeals_api do
    desc 'Generate rswag docs and schemas for appeals_api'
    task run: %i[write_json_schema rswag]

    task write_json_schema: :environment do
      # require AppealsApi::Engine.root.join('spec', 'support', 'rswag_config.rb')
      # AppealsApi::RswagConfig.new.write_schema
    end

    task rswag: :environment do
      ENV['PATTERN'] = 'modules/appeals_api/spec/docs'
      ENV['RAILS_MODULE'] = 'appeals_api'
      ENV['SWAGGER_DRY_RUN'] = '0'
      Rake::Task['rswag:specs:swaggerize'].invoke
    end
  end
end
