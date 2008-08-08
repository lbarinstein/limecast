ActionController::Routing::Routes.draw do |map|
  # Resources
  map.resources :categories
  map.resources :comments
  map.resources :podcasts
  map.resources :tags

  map.namespace :admin do |admin|
    admin.root :controller => 'admin', :action => 'index'
    admin.resources :podcasts
    admin.resources :episodes
    admin.resources :tags, :member => { :merge => :any }
    admin.resources :users
  end

  map.resources :users
  map.resource  :session
  map.search    '/search/:query', :controller => 'podcasts', :action => 'search'
  map.signup    '/signup',        :controller => 'users',    :action => 'new'
  map.login     '/login',         :controller => 'sessions', :action => 'new'
  map.logout    '/logout',        :controller => 'sessions', :action => 'destroy'
  map.activate  '/activate/:activation_code', :controller => 'users', :action => 'activate'

  map.root                        :controller => 'home',     :action => 'home'
  map.add_podcast '/add',         :controller => 'podcasts', :action => 'new'
  map.all         '/all',         :controller => 'podcasts', :action => 'index'
  map.search      '/search',      :controller => 'podcasts', :action => 'search'
  map.all_users   '/users',       :controller => 'users',    :action => 'index'
  map.user        '/user/:user',  :controller => 'users',    :action => 'show'
  map.tag         '/tag/:tag',    :controller => 'tags',     :action => 'show'
  map.use         '/use',         :controller => 'home',     :action => 'use'
  map.privacy     '/privacy',     :controller => 'home',     :action => 'privacy'
  map.team        '/team',        :controller => 'home',     :action => 'team'
  map.guide       '/guide',       :controller => 'home',     :action => 'guide'

  map.podcast          '/:podcast',          :controller => 'podcasts', :action => 'show'
  map.podcast_episodes '/:podcast/episodes', :controller => 'episodes', :action => 'index'
  map.podcast_reviews  '/:podcast/reviews',  :controller => 'comments', :action => 'index'
  map.episode          '/:podcast/:episode', :controller => 'episodes', :action => 'show'
end
