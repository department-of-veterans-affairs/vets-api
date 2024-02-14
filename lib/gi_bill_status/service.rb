require 'common/client/base'
require 'common/client/concerns/monitoring'


module GiBillStatus

    class Service < Common::Client::Base
        include SentryLogging
        include Common::Client::Concerns::Monitoring

        configuration GiBillStatus::Configuration

        def get_gi_bill_status(icn:)
            headers = configuration.base_request_headers
            begin
                response = perform(:get, 'education/chapter_33', {icn: icn}, headers)
            rescue => e
                byebug
            end
        end
    end
end