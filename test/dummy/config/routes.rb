Rails.application.routes.draw do
  mount ActiveBilling::Engine => "/active_billing"
end
