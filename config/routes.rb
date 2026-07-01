Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "patients#index"

  resources :patients, only: %i[index show create] do
    resources :documents, only: %i[create]
    resources :summaries, only: %i[create]
  end

  resources :summaries, only: %i[show]

  namespace :api do
    namespace :v1 do
      resources :documents, only: %i[create]
      resources :summaries, only: %i[create show]
    end
  end
end
