# frozen_string_literal: true

require 'rails_helper'
require 'nokogiri'

RSpec.describe 'Flipper UI' do
  def bypass_flipper_authenticity_token
    Rails.application.routes.draw do
      mount Flipper::UI.app(
        Flipper.instance,
        rack_protection: { except: :authenticity_token }
      ) => '/flipper', constraints: Flipper::AdminUserConstraint
    end
    yield
    Rails.application.reload_routes!
  end

  include Warden::Test::Helpers

  let(:default_attrs) do
    { 'login' => 'john',
      'name' => 'John Doe',
      'gravatar_id' => '38581cb351a52002548f40f8066cfecg',
      'avatar_url' => 'http://example.com/avatar.jpg',
      'email' => 'john@doe.com',
      'company' => 'Doe, Inc.' }
  end
  let(:user) { Warden::GitHub::User.new(default_attrs) }

  github_oauth_message = "If you'd like to modify feature toggles, please sign in with GitHub"

  before do
    allow_any_instance_of(Warden::Proxy).to receive(:authenticate!).and_return(user)
    allow_any_instance_of(Warden::Proxy).to receive(:user).and_return(user)
    allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(false)
    allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(false)
  end

  context 'GET /flipper/features' do
    context 'Unauthenticated user' do
      it 'is told to sign in with GitHub to access features' do
        get '/flipper/features'
        expect(response.body).to include(github_oauth_message)
        assert_response :success
      end

      it 'is shown a button to sign in with GitHub' do
        get '/flipper/features'
        body = Nokogiri::HTML(response.body)
        signin_button = body.at_css('button:contains("Sign in to GitHub")')
        expect(signin_button).not_to be_nil
        assert_response :success
      end

      it 'can see a list of features, but they are NOT clickable (NOT hrefs to feature page)' do
        get '/flipper/features'
        body = Nokogiri::HTML(response.body)
        feature_link = body.at_css('a[href*="/flipper/features/this_is_only_a_test"]')
        expect(response.body).to include('this_is_only_a_test')
        expect(feature_link).to be_nil
        assert_response :success
      end
    end

    context 'Authenticated user (through GitHub Oauth)' do
      before do
        # Mimic the functionality of the end of the OAuth handshake, where #finalize_flow! (`warden_github.rb`)
        # is called, setting the value of request.session[:flipper_user] to the mocked Warden::Github user
        allow_any_instance_of(ActionDispatch::Request).to receive(:session) { { flipper_user: user } }
      end

      it 'is not shown a notice to sign into GitHub' do
        get '/flipper/features'
        expect(response.body).not_to include(github_oauth_message)
        assert_response :success
      end

      it 'is not shown a button to sign in with GitHub' do
        get '/flipper/features'
        body = Nokogiri::HTML(response.body)
        signin_button = body.at_css('button:contains("Sign in to GitHub")')
        expect(signin_button).to be_nil
        assert_response :success
      end

      context 'Authorized user (organization and team membership)' do
        before do
          allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
          allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(true)
        end

        it 'can see a list of features and they are clickable (hrefs to feature page)' do
          get '/flipper/features'
          body = Nokogiri::HTML(response.body)
          feature_link = body.at_css('a[href*="/flipper/features/this_is_only_a_test"]')
          expect(feature_link).not_to be_nil
          assert_response :success
        end
      end

      context 'Unauthorized user' do
        unauthorized_message = 'You are not authorized to perform any actions'

        it 'can see a list of features, but they are NOT clickable (NOT hrefs to feature page)' do
          get '/flipper/features'
          body = Nokogiri::HTML(response.body)
          feature_link = body.at_css('a[href*="/flipper/features/this_is_only_a_test"]')
          expect(response.body).to include('this_is_only_a_test')
          expect(feature_link).to be_nil
          assert_response :success
        end

        context 'without organization membership' do
          it 'is told that they are unauthorized and links to documentation' do
            allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(false)

            get '/flipper/features'
            body = Nokogiri::HTML(response.body)
            docs_link = body.at_css('a[href*="depo-platform-documentation"]')
            expect(response.body).to include(unauthorized_message)
            expect(docs_link).not_to be_nil
          end
        end

        context 'without team membership' do
          it 'is told that they are unauthorized and links to documentation' do
            allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
            allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(false)

            get '/flipper/features'
            body = Nokogiri::HTML(response.body)
            docs_link = body.at_css('a[href*="depo-platform-documentation"]')
            expect(response.body).to include(unauthorized_message)
            expect(docs_link).not_to be_nil
          end
        end
      end
    end
  end

  context 'GET flipper/features/:some_feature' do
    context 'Unauthenticated user' do
      it 'is told to sign in with GitHub to access features' do
        get '/flipper/features/this_is_only_a_test'
        expect(response.body).to include(github_oauth_message)
        assert_response :success
      end

      it 'is shown a button to sign in with GitHub' do
        get '/flipper/features/this_is_only_a_test'
        body = Nokogiri::HTML(response.body)
        signin_button = body.at_css('button:contains("Sign in to GitHub")')
        expect(signin_button).not_to be_nil
        assert_response :success
      end

      it 'cannot see the feature name in the title (h1) or button to enable/disable' do
        get '/flipper/features/this_is_only_a_test'
        body = Nokogiri::HTML(response.body)
        title = body.at_css('h1:contains("this_is_only_a_test")')
        toggle_button = body.at_css('button:contains("for everyone")')
        expect(title).to be_nil
        expect(toggle_button).to be_nil
        assert_response :success
      end
    end

    context 'Authenticated user (through GitHub Oauth)' do
      before do
        # Mimic the functionality of the end of the OAuth handshake, where #finalize_flow! (`warden_github.rb`)
        # is called, setting the value of request.session[:flipper_user] to the mocked Warden::Github user
        allow_any_instance_of(ActionDispatch::Request).to receive(:session) { { flipper_user: user } }
      end

      it 'is not shown a notice to sign into GitHub' do
        get '/flipper/features/this_is_only_a_test'
        expect(response.body).not_to include(github_oauth_message)
        assert_response :success
      end

      it 'is not shown a button to sign in with GitHub' do
        get '/flipper/features/this_is_only_a_test'
        body = Nokogiri::HTML(response.body)
        signin_button = body.at_css('button:contains("Sign in to Github")')
        expect(signin_button).to be_nil
        assert_response :success
      end

      context 'Authorized user (organization and team membership)' do
        before do
          allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
          allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(true)
          Flipper.disable(:this_is_only_a_test)
        end

        it 'can see the feature name in title and button to enable/disable feature' do
          get '/flipper/features/this_is_only_a_test'
          body = Nokogiri::HTML(response.body)
          title = body.at_css('h1:contains("this_is_only_a_test")')
          toggle_button = body.at_css('button:contains("Enable for everyone")')
          expect(title).not_to be_nil
          expect(toggle_button).not_to be_nil
          assert_response :success
        end
      end

      context 'Unauthorized user' do
        unauthorized_message = 'You are not authorized to perform any actions'

        it 'cannot see the feature name in the title (h1) or button to enable/disable' do
          get '/flipper/features/this_is_only_a_test'
          body = Nokogiri::HTML(response.body)
          title = body.at_css('h1:contains("this_is_only_a_test")')
          toggle_button = body.at_css('button:contains("for everyone")')
          expect(title).to be_nil
          expect(toggle_button).to be_nil
          assert_response :success
        end

        context 'without organization membership' do
          it 'is told that they are unauthorized and links to documentation' do
            allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(false)

            get '/flipper/features/this_is_only_a_test'
            body = Nokogiri::HTML(response.body)
            docs_link = body.at_css('a[href*="depo-platform-documentation"]')
            expect(response.body).to include(unauthorized_message)
            expect(docs_link).not_to be_nil
          end
        end

        context 'without team membership' do
          it 'is told that they are unauthorized and links to documentation' do
            allow(user).to receive(:organization_member?).with(Settings.sidekiq.github_organization).and_return(true)
            allow(user).to receive(:team_member?).with(Settings.sidekiq.github_team).and_return(false)

            get '/flipper/features/this_is_only_a_test'
            body = Nokogiri::HTML(response.body)
            docs_link = body.at_css('a[href*="depo-platform-documentation"]')
            expect(response.body).to include(unauthorized_message)
            expect(docs_link).not_to be_nil
          end
        end
      end
    end
  end

  context 'POST flipper/features/:some_feature' do
    context 'Unauthenticated User' do
      it 'cannot toggle features and returns 403' do
        bypass_flipper_authenticity_token do
          expect do
            post '/flipper/features/this_is_only_a_test/boolean'
          end.to raise_error(Common::Exceptions::Forbidden)
        end
      end
    end

    context 'Authenticated User' do
      before do
        allow_any_instance_of(ActionDispatch::Request).to receive(:session) { { flipper_user: user } }
      end

      context 'Unauthorized User' do
        it 'cannot toggle features and returns 403' do
          bypass_flipper_authenticity_token do
            expect do
              post '/flipper/features/this_is_only_a_test/boolean'
            end.to raise_error(Common::Exceptions::Forbidden)
          end
        end
      end

      context 'Authorized User' do
        it 'can toggle features' do
          allow(user).to receive(:organization_member?).with(Settings.flipper.github_organization).and_return(true)
          allow(user).to receive(:team_member?).with(Settings.flipper.github_team).and_return(true)
          Flipper.enable(:this_is_only_a_test)

          bypass_flipper_authenticity_token do
            expect(Flipper.enabled?(:this_is_only_a_test)).to be true
            post '/flipper/features/this_is_only_a_test/boolean', params: nil
            assert_response :found
            expect(Flipper.enabled?(:this_is_only_a_test)).to be false
          end
        end
      end
    end
  end
end
