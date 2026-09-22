require_relative "lib/active_billing/version"

Gem::Specification.new do |spec|
  spec.name        = "active_billing"
  spec.version     = ActiveBilling::VERSION
  spec.authors     = ["Your Name"]
  spec.email       = ["your.email@example.com"]
  spec.homepage    = "https://github.com/yourusername/active_billing"
  spec.summary     = "SaaS billing engine for Rails: cycles, plan + usage consumption, invoices, payments"
  spec.description = "ActiveBilling is a Rails engine gem for SaaS billing. It models configured billing cycles, plan-based and usage-based consumption, cycle close, invoice generation, and payment state. Runs embedded inside a Rails app or standalone as a mountable JSON API service."
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2"

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "receipts", "~> 2.4"
  spec.add_dependency "matrix" # required by prawn on Ruby >= 3.1

  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "factory_bot_rails"
end
