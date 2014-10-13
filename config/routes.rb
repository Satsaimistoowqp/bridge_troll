Bridgetroll::Application.routes.draw do
  root to: "events#index"

  devise_for :users, controllers: {
    registrations: "devise_overrides/registrations",
    omniauth_callbacks: "devise_overrides/omniauth_callbacks"
  }

  resources :users, only: [:index] do
    resource :profile, :only => [:show]
  end
  resources :meetup_users, :only => [:show]

  resources :locations
  resources :chapters

  resources :events do
    resources :organizers, :only => [:index, :create, :destroy]
    resources :checkiners, :only => [:index, :create, :destroy]
    resources :volunteers, :only => [:index, :update]

    resources :students, :only => [:index], :controller => 'events/students'
    resources :attendees, :only => [:index, :update], :controller => 'events/attendees'
    resources :emails, :only => [:new, :create, :show], :controller => 'events/emails'

    resources :sections, :only => [:create, :update, :destroy] do
      post :arrange, on: :collection
    end

    resources :rsvps, :except => [:index, :new] do
      new do
        get :volunteer
        get :learn
      end
      resources :surveys, :only => [:new, :create]
    end

    resources :surveys, :only => :index

    resources :event_sessions, :only => [:index, :show] do
      resources :checkins, :only => [:index, :create, :destroy]
    end

    resources :organizer_tools, :only => [:index], controller: "events/organizer_tools"
    controller "events/organizer_tools" do
      get "send_survey_email"
      get "organize_sections"
      get 'diets'
    end

    collection do
      get "past_events"
      get "all_events"
      resources :unpublished_events, only: [:index], controller: "events/unpublished_events" do
        post "publish"
        post "flag"
      end
    end

    member do
      get "levels"
    end
  end

  resources :external_events

  get "/about" => "static_pages#about"
  get "/admin_dashboard" => "admin_pages#admin_dashboard"

  if Rails.env.development?
    get "/style_guide" => "static_pages#style_guide"
  end
end
