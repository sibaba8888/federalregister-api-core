FederalregisterApiCore::Application.routes.draw do
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  namespace :admin do
    match '' => 'special#home', :as => :home, :via => :get
      resources :agencies do
        member do
          get :delete
        end
    end
    resources :agency_names do
      collection do
        get :unprocessed
      end
    end
    namespace :agency_names do
      resources :issues
    end
    resources :canned_searches, :only => [:new]
    match 'canned_searches/:slug' => 'canned_searches#section', :as => :section_canned_searches, :via => :get
    resources :canned_searches do
      member do
        get :delete
      end
    end
    resources :dictionary_words, :only => [:create]
    resources :spelling_suggestions, :only => [:index]
    match 'index/:year' => 'indexes#year', :as => :index_year, :via => :get
    match 'index/:year/publish' => 'indexes#publish', :as => :publish_index_year, :via => :post
    match 'index/:year/sgml' => 'indexes#sgml', :as => :sgml_index, :via => :get
    match 'index/:year/:agency' => 'indexes#year_agency', :via => [:get]
    match 'index/:year/:agency' => 'indexes#update_year_agency', :as => :index_year_agency, :via => [:put]
    match 'index/:year/:agency/unapproved-documents' => 'indexes#year_agency_unapproved_documents', :as => :index_year_agency_unapproved_documents, :via => :get
    match 'index/:year/:agency/completion' => 'indexes#mark_complete', :as => :index_year_agency_completion, :via => :put
    match 'index/:year/:agency/:type' => 'indexes#year_agency_type', :as => :index_year_agency_type, :via => :get
    resources :generated_files, :only => [:show]
    resources :topics
    resources :topic_names do
      collection do
        get :unprocessed
      end
    end
    resources :presidential_documents, :only => [:index, :create, :show]
    resources :photo_candidates, :only => [:show, :info] do
      member do
        get :info
      end
    end
    resources :sections
    resources :missing_images, :only => :index
    resources :reprocessed_issues, :only => [:index, :show, :create, :update]
    match 'reprocessed_issues_update_mods/:id' => 'reprocessed_issues#update_mods', :as => :update_mods, :via => :put
    resources :issues do
        member do
          get :preview
        end
      resource :approval, controller: 'issues/approvals'
      resources :entries, controller: 'issues/entries'
      resources :sections, controller: 'issues/sections' do
        member do
          get :preview
        end
        resources :highlights, controller: 'issues/sections/highlights'
      end
    end

    match 'entries/:id/highlight' => 'issues/entries#highlight', :as => :highlight_entry, :via => :get
    resources :password_resets, :except => [:index, :show, :destroy]
    resources :users do
      resource :password, controller: 'users/passwords'
    end
    resource :user_session
    resources :site_notifications, :only => [:edit, :index, :update]
    match 'login' => 'user_sessions#new', :as => :login, :via => :get
    match 'logout' => 'user_sessions#destroy', :as => :logout, :via => :get
  end

end

