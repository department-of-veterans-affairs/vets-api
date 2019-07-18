module FeatureLogin
  def feature_set_user_session(user = FactoryBot.create(:user, :loa3))
    extend AuthenticatedSessionHelper
    cookie = sign_in(user, nil, true)

    visit(DEFAULT_HOST)
    Capybara.current_session.driver.browser.manage.add_cookie(name: Settings.sso.cookie_name, value: 'foo')
    Capybara.current_session.driver.browser.manage.add_cookie(name: 'api_session', value: cookie.split(';')[0].split('=')[1])
    page.execute_script("localStorage.setItem('hasSession', true)")
  end
end
