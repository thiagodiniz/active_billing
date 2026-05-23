namespace :active_billing do
  desc 'Install ActiveBilling migrations'
  task :install => :environment do
    puts 'Copying migrations...'
    # This will be handled by Rails engine if converted to engine
    # Or use: rails active_billing:install:migrations
  end

  desc 'Generate usage records for current month'
  task generate_monthly_usage: :environment do
    puts 'Generating usage records for current month...'
    # Add your logic to generate usage records
    # Example:
    # Customer.find_each do |customer|
    #   customer.usages.find_or_create_by(month: Date.current.beginning_of_month)
    # end
    puts 'Done!'
  end

  desc 'Generate invoices from pending usages'
  task generate_invoices: :environment do
    puts 'Generating invoices from pending usages...'
    # Add your logic to generate invoices
    # Example:
    # ActiveBilling::Usage.without_invoices.find_each do |usage|
    #   invoice = usage.billable_entity.invoices.create(add_usages_ids: [usage.id])
    #   puts "Created invoice #{invoice.id} for usage #{usage.id}"
    # end
    puts 'Done!'
  end
end
