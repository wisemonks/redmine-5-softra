# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get '/mail_tracker', :to => 'mail_tracker#index'
get '/issues_collision_check', :to => 'issue_collisions#check'
post '/oauth/callback', :to => 'mail_sources#activate_oauth'
get '/oauth/callback', :to => 'mail_sources#activate_oauth'

resources :mail_sources do
  collection do
    get 'activate', to: 'mail_sources#activate'
    get 'deactivate', to: 'mail_sources#deactivate'
    get 'add_new', to: 'mail_sources#add_new'
  end
end

resources :mail_tracking_rules do
  collection do
    get 'add_rule'
  end
end

scope '/projects/:project_id', :as => 'project' do
  resource :project_email, :as => 'outbound_email', :only => [:update, :destroy] do
    put 'watchers'
  end
end

resources :email_templates, only: [:create, :destroy]
resources :mail_source_blacklists
