require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :active_billing do
  desc 'Generate migrations for ActiveBilling'
  task :install do
    puts 'Run: rails active_billing:install:migrations'
  end
end
