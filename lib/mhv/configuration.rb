# frozen_string_literal: true
require 'common/client/configuration'
module MHV
  # Configuration class used to setup the environment used by client
  class Configuration < Common::Client::Configuration
    QUERY_HASH = {
      p_auth: '195zOwfW',
      p_p_id: 'mhvUserRegistration_WAR_mhvusermgmtportalportlet',
      p_p_lifecycle: 1,
      p_p_state: 'normal',
      p_p_mode: 'view',
      p_p_col_id: 'column-1',
      p_p_col_count: 2,
      _mhvUserRegistration_WAR_mhvusermgmtportalportlet__facesViewIdRender: '/views/user/userRegistration.xhtml'
    }.freeze

    def base_path
      "#{@host}/mhv-portal-web/user-registration?#{query_string}"
    end

    def query_string
      QUERY_HASH.to_query
    end
  end
end
