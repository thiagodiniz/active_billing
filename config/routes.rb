ActiveBilling::Engine.routes.draw do
  # Portal (read-only; every action is scoped by billable_entity_id).
  resources :invoices, only: %i[index show]
  resources :usages,   only: %i[index show]
  resources :charges,  only: %i[index show]

  # Current plan for the billable entity.
  resource :plan, only: %i[show]

  # Standalone JSON API (enabled via config.api_enabled). Manipulates every model
  # while respecting the domain lifecycle; custom transitions use REST noun sub-resources.
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :plans, except: %i[new edit]

      resources :billings, except: %i[new edit] do
        member do
          put :plan # associate a plan
          post :finalization
        end
      end

      resources :usages, except: %i[new edit] do
        member { post :closure }
      end

      resources :events, only: %i[index show create destroy]

      resources :invoices, except: %i[new edit] do
        resources :items, controller: "invoice_items", except: %i[new edit]
        member do
          post :issuance
          post :cancellation
        end
      end

      resources :charges, except: %i[new edit] do
        member { post :payment }
      end
    end
  end
end
